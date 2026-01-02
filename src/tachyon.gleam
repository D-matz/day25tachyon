import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/set.{type Set}
import gleam/string
import lustre
import lustre/attribute as a
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html as h
import lustre/event

// MAIN ------------------------------------------------------------------------

pub fn main() {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", init_input)

  Nil
}

const init_input = ".......S.......
...............
.......^.......
...............
......^.^......
...............
.....^.^.^.....
...............
....^.^...^....
...............
...^.^...^.^...
...............
..^...^.....^..
...............
.^.^.^.^.^...^.
..............."

// MODEL -----------------------------------------------------------------------

type Beams {
  Normal(Set(Int))
  Quantum(Dict(Int, Int))
}

type Model {
  Model(
    in: String,
    curr_b: Beams,
    lines_todo: List(String),
    lines_done: List(Element(Msg)),
    on_index: Int,
    count: Int,
  )
}

fn init(starting_example) -> #(Model, Effect(Msg)) {
  let starting_index = 0
  let m = new_model(starting_example, starting_index, Normal(set.new()))
  let tick_ms = 3000 / list.length(m.lines_todo)
  #(m, tick(TimerTick(tick_ms, starting_index)))
}

// UPDATE ----------------------------------------------------------------------

type TimerTick {
  TimerTick(millisec: Int, index: Int)
}

type Counter {
  Splits(Int)
  QTimelines(Int)
}

type Msg {
  ClockTickedForward(TimerTick)
  UserEnteredInput(String)
  UserClickedQuantum
  UserClickedReplay
}

fn update(m: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    ClockTickedForward(timer) -> {
      case timer.index == m.on_index {
        False -> #(m, effect.none())
        True -> {
          case m.lines_todo {
            [] -> #(m, effect.none())
            [line, ..lines_todo] -> {
              let #(curr_beams, this_line_count) = next_beams(line, m.curr_b)
              let new_count = case this_line_count {
                QTimelines(ct) -> ct
                Splits(ct) -> m.count + ct
              }
              let curr_line =
                list.fold(
                  from: #([], 0),
                  over: line |> string.to_graphemes,
                  with: fn(acc, letter) {
                    let letter_num = acc.1 + 1
                    let new_letter = case letter {
                      "S" -> h.text("S")
                      "s" -> h.text("s")
                      _ -> {
                        case curr_beams {
                          Normal(beams) ->
                            case beams |> set.contains(letter_num) {
                              True -> h.text("|")
                              False -> h.text(letter)
                            }
                          Quantum(beams) -> {
                            case beams |> dict.get(letter_num) {
                              Ok(n) -> {
                                let color_hex =
                                  { 0xBF - { { 0xBF * n } / new_count } }
                                  |> int.to_base16
                                h.span(
                                  [
                                    a.style(
                                      "color",
                                      "#" <> color_hex <> color_hex <> color_hex,
                                    ),
                                  ],
                                  [h.text("|")],
                                )
                              }
                              Error(_) -> h.text(letter)
                            }
                          }
                        }
                      }
                    }
                    #([new_letter, ..acc.0], letter_num)
                  },
                ).0
              let ascii_line = [h.text("\n"), ..curr_line] |> list.reverse
              let lines_done = m.lines_done |> list.append(ascii_line)
              #(
                Model(
                  in: m.in,
                  on_index: m.on_index,
                  curr_b: curr_beams,
                  lines_done:,
                  lines_todo:,
                  count: new_count,
                ),
                tick(timer),
              )
            }
          }
        }
      }
    }
    UserEnteredInput(input) -> {
      let new_index = m.on_index + 1
      let m =
        new_model(input, new_index, case m.curr_b {
          Normal(_) -> Normal(set.new())
          Quantum(_) -> Quantum(dict.new())
        })
      let tick_ms = 3000 / list.length(m.lines_todo)
      #(m, tick(TimerTick(tick_ms, new_index)))
    }
    UserClickedQuantum -> {
      let new_index = m.on_index + 1
      let m =
        new_model(m.in, new_index, case m.curr_b {
          Quantum(_) -> Normal(set.new())
          Normal(_) -> Quantum(dict.new())
        })
      let tick_ms = 3000 / list.length(m.lines_todo)
      #(m, tick(TimerTick(tick_ms, new_index)))
    }
    UserClickedReplay -> {
      let new_index = m.on_index + 1
      let m =
        new_model(m.in, new_index, case m.curr_b {
          Normal(_) -> Normal(set.new())
          Quantum(_) -> Quantum(dict.new())
        })
      let tick_ms = 3000 / list.length(m.lines_todo)
      #(m, tick(TimerTick(tick_ms, new_index)))
    }
  }
}

fn tick(t: TimerTick) -> Effect(Msg) {
  use dispatch <- effect.from
  use <- set_timeout(t.millisec)

  dispatch(ClockTickedForward(t))
}

@external(javascript, "./app.ffi.mjs", "set_timeout")
fn set_timeout(_delay: Int, _cb: fn() -> a) -> Nil {
  Nil
}

fn new_model(input: String, curr_index: Int, new_beams: Beams) {
  Model(
    in: input,
    curr_b: new_beams,
    lines_todo: input |> string.split("\n"),
    lines_done: [],
    on_index: curr_index,
    count: 0,
  )
}

fn next_beams(input: String, old: Beams) {
  case old {
    Normal(old_beams) -> {
      let split_beams =
        list.fold(
          from: #(set.new(), 0, 0),
          over: input |> string.to_graphemes,
          with: fn(acc, letter) {
            let letter_num = acc.1 + 1
            let acc_set = acc.0
            let split_count = acc.2
            let #(new_acc_set, new_split_count) = case
              old_beams |> set.contains(letter_num)
            {
              False -> {
                let new_letter = case letter {
                  "S" -> acc_set |> set.insert(letter_num)
                  "s" -> acc_set |> set.insert(letter_num)
                  _ -> acc_set
                }
                #(new_letter, split_count)
              }
              True ->
                case letter {
                  "^" -> #(
                    acc_set
                      |> set.delete(letter_num)
                      |> set.insert(letter_num + 1)
                      |> set.insert(letter_num - 1),
                    // this might insert a line on top of another char x or space or something
                    // so we'll go remove those from set later
                    split_count + 1,
                  )
                  "." -> #(acc_set |> set.insert(letter_num), split_count)
                  _ -> #(acc_set, split_count)
                  // not in problem but stopping on other chars
                }
            }
            #(new_acc_set, letter_num, new_split_count)
          },
        )
      let split_beams =
        list.index_fold(
          from: split_beams,
          over: input |> string.to_graphemes,
          with: fn(acc, letter, index) {
            //let letter_num = acc.1 + 1
            let acc_set = acc.0
            let split_count = acc.2
            case letter {
              "." -> acc
              "S" -> acc
              "s" -> acc
              // because we might have put a beam on a random char earlier
              // which I want to block them
              // also turns out index fold exists dont need awkward tuple but whatever
              _ -> {
                #(acc_set |> set.delete(index + 1), 0, split_count - 1)
              }
            }
          },
        )
      #(Normal(split_beams.0), Splits(split_beams.2))
    }
    Quantum(old_beams) -> {
      let split_beams =
        list.fold(
          from: #(dict.new(), 0),
          over: input |> string.to_graphemes,
          with: fn(acc, letter) {
            let letter_num = acc.1 + 1
            let acc_dict = acc.0
            let new_acc_dict = case old_beams |> dict.get(letter_num) {
              Error(_) -> {
                case letter {
                  "S" -> acc_dict |> dict.insert(letter_num, 1)
                  "s" -> acc_dict |> dict.insert(letter_num, 1)
                  _ -> acc_dict
                }
              }
              Ok(beam_count) ->
                case letter {
                  "^" -> {
                    let left = letter_num - 1
                    let left_beams_new = case acc_dict |> dict.get(left) {
                      Ok(left_count) -> left_count + beam_count
                      Error(_) -> beam_count
                    }
                    let right = letter_num + 1
                    let right_beams_new = case acc_dict |> dict.get(right) {
                      Ok(right_count) -> right_count + beam_count
                      Error(_) -> beam_count
                    }
                    acc_dict
                    |> dict.insert(left, left_beams_new)
                    |> dict.insert(right, right_beams_new)
                    |> dict.delete(letter_num)
                  }
                  "." -> {
                    let beams_line_dict_and_above = case
                      acc_dict |> dict.get(letter_num)
                    {
                      Ok(dict_beams) -> {
                        //needed if we have beam_count from above + beams inserted by left splitter
                        dict_beams + beam_count
                      }
                      Error(_) -> {
                        beam_count
                      }
                    }
                    acc_dict
                    |> dict.insert(letter_num, beams_line_dict_and_above)
                  }
                  _ -> acc_dict
                  // not in problem but stopping on other chars
                }
            }
            #(new_acc_dict, letter_num)
          },
        )
      let split_beams =
        list.index_fold(
          from: split_beams,
          over: input |> string.to_graphemes,
          with: fn(acc, letter, index) {
            let acc_dict = acc.0
            case letter {
              "." -> acc
              "S" -> acc
              "s" -> acc
              // because we might have put a beam on a random char earlier
              // which I want to block them
              // also turns out index fold exists dont need awkward tuple but whatever
              _ -> {
                #(acc_dict |> dict.delete(index + 1), 0)
              }
            }
          },
        )
      let count_quantum_beams =
        dict.fold(from: 0, over: split_beams.0, with: fn(acc, _, v) { acc + v })
      #(Quantum(split_beams.0), QTimelines(count_quantum_beams))
    }
  }
}

// VIEW ------------------------------------------------------------------------

fn view(model: Model) -> Element(Msg) {
  h.article(
    [
      a.style("display", "flex"),
      a.style("flex-direction", "column"),
      a.style("gap", "5px"),
    ],
    [
      h.h1([], [h.a([a.href("/")], [h.text("Correct Arity")])]),
      h.p([], [
        h.a([a.href("https://adventofcode.com/2025/day/7")], [
          h.text("Advent of Code day 7"),
        ]),
        h.text(" visualization: (quantum) tachyon manifold particle splitting "),
        h.a(
          [
            a.href(
              "https://github.com/D-matz/day25tachyon/blob/main/src/tachyon.gleam",
            ),
          ],
          [h.text("(source)")],
        ),
      ]),
      h.div([], [
        h.button(
          [
            event.on_click(UserClickedQuantum),
            a.style("width", "115px"),
            a.style("padding", "3px"),
          ],
          [
            h.text(case model.curr_b {
              Normal(_) -> "Enable Quantum"
              Quantum(_) -> "Disable Quantum"
            }),
          ],
        ),
        h.button(
          [
            event.on_click(UserClickedReplay),
            a.style("width", "fit-content"),
            a.style("margin", "5px"),
            a.style("padding", "3px"),
          ],
          [
            h.text("Replay"),
          ],
        ),
        h.text(
          case model.curr_b {
            Normal(_) -> "split count: "
            Quantum(_) -> "timeline count: "
          }
          <> model.count |> int.to_string,
        ),
      ]),
      h.div(
        [
          a.style("display", "flex"),
          a.style("flex-wrap", "wrap"),
          a.style("gap", "8px"),
          a.style("align-items", "flex-start"),
        ],
        [
          h.textarea(
            [
              a.id("input"),
              a.style("height", "260px"),
              a.style("width", "130px"),
              event.on_input(UserEnteredInput),
            ],
            model.in,
          ),
          h.pre(
            [
              a.style("margin-top", "0px"),
              // a.style("max-height", "65vh"),
              // a.style("overflow", "auto"),
              case model.curr_b {
                Normal(_) -> a.style("border", "1px solid #2f2f2f")
                Quantum(_) ->
                  a.styles([
                    #("border", "1px solid #a6f0fc"),
                    #("box-shadow", "0 0 50px #a6f0fc"),
                  ])
              },
            ],
            model.lines_done
              |> list.append([
                h.text(
                  model.lines_todo
                  |> string.join("\n"),
                ),
              ]),
          ),
        ],
      ),
    ],
  )
}
