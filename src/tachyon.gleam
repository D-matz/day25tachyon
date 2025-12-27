// IMPORTS ---------------------------------------------------------------------

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

type Model {
  Model(
    in: String,
    curr_beams: Set(Int),
    lines_todo: List(String),
    lines_done: List(String),
    on_index: Int,
    num_splits: Int,
    is_quantum: Bool,
  )
}

fn init(starting_example) -> #(Model, Effect(Msg)) {
  let starting_index = 0
  let m = new_model(starting_example, starting_index, False)
  let tick_ms = 3000 / list.length(m.lines_todo)
  #(m, tick(TimerTick(tick_ms, starting_index)))
}

// UPDATE ----------------------------------------------------------------------

type TimerTick {
  TimerTick(millisec: Int, index: Int)
}

type Msg {
  ClockTickedForward(TimerTick)
  UserEnteredInput(String)
  UserClickedQuantum
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
              let #(curr_beams, this_line_splits) =
                next_beams(line, m.curr_beams)
              let curr_line =
                list.fold(
                  from: #("", 0),
                  over: line |> string.to_graphemes,
                  with: fn(acc, letter) {
                    let letter_num = acc.1 + 1
                    let new_letter = case letter {
                      "S" -> "S"
                      "s" -> "s"
                      _ -> {
                        case curr_beams |> set.contains(letter_num) {
                          True -> "|"
                          False -> letter
                        }
                      }
                    }
                    #(acc.0 <> new_letter, letter_num)
                  },
                ).0
              let lines_done = m.lines_done |> list.append([curr_line])
              #(
                Model(
                  in: m.in,
                  on_index: m.on_index,
                  is_quantum: m.is_quantum,
                  curr_beams:,
                  lines_done:,
                  lines_todo:,
                  num_splits: m.num_splits + this_line_splits,
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
      let m = new_model(input, new_index, m.is_quantum)
      let tick_ms = 3000 / list.length(m.lines_todo)
      #(m, tick(TimerTick(tick_ms, new_index)))
    }
    UserClickedQuantum -> {
      let new_index = m.on_index + 1
      let m = new_model(m.in, new_index, !m.is_quantum)
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

fn new_model(input: String, curr_index: Int, is_quantum: Bool) {
  Model(
    is_quantum,
    in: input,
    curr_beams: set.new(),
    lines_todo: input |> string.split("\n"),
    lines_done: [],
    on_index: curr_index,
    num_splits: 0,
  )
}

fn next_beams(input: String, old_beams: Set(Int)) {
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
                split_count + 1,
              )
              _ -> #(acc_set |> set.insert(letter_num), split_count)
            }
        }
        #(new_acc_set, letter_num, new_split_count)
      },
    )
  #(split_beams.0, split_beams.2)
}

// VIEW ------------------------------------------------------------------------

fn view(model: Model) -> Element(Msg) {
  h.article([], [
    h.h1([], [h.a([a.href("/")], [h.text("Correct Arity")])]),
    h.p([], [
      h.text("split count: " <> model.num_splits |> int.to_string),
      h.br([]),
      h.button([event.on_click(UserClickedQuantum)], [
        h.text(case model.is_quantum {
          False -> "Enable Quantum Tachyon Manifold"
          True -> "Disable Quantum Tachyon Manifold"
        }),
      ]),
    ]),
    h.div(
      [
        a.style("display", "flex"),
        a.style("flex-wrap", "wrap"),
        a.style("gap", "8px"),
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
          ],
          [
            h.text(
              model.lines_done
              |> list.append(model.lines_todo)
              |> string.join("\n"),
            ),
          ],
        ),
      ],
    ),
  ])
}
