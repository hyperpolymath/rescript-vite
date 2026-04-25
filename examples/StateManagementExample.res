// SPDX-License-Identifier: PMPL-1.0-or-later
// Global state management example — demonstrates reducer pattern for complex state

type appState = {
  counter: int,
  todos: array<todo>,
  user: option<user>,
}

and todo = {
  id: int,
  title: string,
  completed: bool,
}

and user = {
  id: int,
  name: string,
  email: string,
}

type action =
  | IncrementCounter
  | DecrementCounter
  | ResetCounter
  | AddTodo(string)
  | RemoveTodo(int)
  | ToggleTodo(int)
  | SetUser(user)
  | ClearUser

let initialState: appState = {
  counter: 0,
  todos: [],
  user: None,
}

let reducer = (state: appState, action: action): appState => {
  switch action {
  | IncrementCounter => {...state, counter: state.counter + 1}
  | DecrementCounter => {...state, counter: state.counter - 1}
  | ResetCounter => {...state, counter: 0}
  | AddTodo(title) =>
    let newTodo: todo = {
      id: state.todos |> Array.length,
      title,
      completed: false,
    }
    {...state, todos: Array.concat(state.todos, [newTodo])}
  | RemoveTodo(id) =>
    {...state, todos: state.todos |> Array.filter(t => t.id != id)}
  | ToggleTodo(id) =>
    {
      ...state,
      todos: state.todos |> Array.map(t =>
        t.id == id ? {...t, completed: !t.completed} : t
      ),
    }
  | SetUser(user) => {...state, user: Some(user)}
  | ClearUser => {...state, user: None}
  }
}

@react.component
let counterSection = (~state: appState, ~dispatch) => {
  <section className="state-section">
    <h3> {"Counter" |> React.string} </h3>
    <p> {state.counter->Int.toString |> React.string} </p>
    <button onClick={_ => dispatch(IncrementCounter)}>
      {"+1" |> React.string}
    </button>
    <button onClick={_ => dispatch(DecrementCounter)}>
      {"-1" |> React.string}
    </button>
    <button onClick={_ => dispatch(ResetCounter)}>
      {"Reset" |> React.string}
    </button>
  </section>
}

@react.component
let todoSection = (~state: appState, ~dispatch) => {
  let (input, setInput) = React.useState(_ => "")

  let handleAdd = () => {
    if String.length(input) > 0 {
      dispatch(AddTodo(input))
      setInput(_ => "")
    }
  }

  <section className="state-section">
    <h3> {"Todos" |> React.string} </h3>
    <div className="todo-input">
      <input
        value={input}
        onChange={e => setInput(_ => ReactEvent.Form.target(e)["value"])}
        placeholder="Add a new todo..."
      />
      <button onClick={_ => handleAdd()}>
        {"Add" |> React.string}
      </button>
    </div>
    <ul>
      {state.todos
        |> Array.mapi((i, todo) =>
          <li
            key={Int.toString(i)}
            className={todo.completed ? "todo-completed" : ""}
            onClick={_ => dispatch(ToggleTodo(todo.id))}>
            {`${todo.title} ${todo.completed ? "✓" : ""}` |> React.string}
          </li>
        )
        |> React.array}
    </ul>
  </section>
}

@react.component
let userSection = (~state: appState, ~dispatch) => {
  <section className="state-section">
    <h3> {"User" |> React.string} </h3>
    {switch state.user {
    | Some(user) =>
      <div>
        <p> {`Name: ${user.name}` |> React.string} </p>
        <p> {`Email: ${user.email}` |> React.string} </p>
        <button onClick={_ => dispatch(ClearUser)}>
          {"Logout" |> React.string}
        </button>
      </div>
    | None =>
      <div>
        <p> {"No user logged in" |> React.string} </p>
        <button
          onClick={_ =>
            dispatch(
              SetUser({
                id: 1,
                name: "John Doe",
                email: "john@example.com",
              })
            )
          }>
          {"Login" |> React.string}
        </button>
      </div>
    }}
  </section>
}

@react.component
let make = () => {
  let (state, dispatch) = React.useReducer(reducer, initialState)

  <div className="state-management-app">
    <h2> {"Global State Management Example" |> React.string} </h2>
    <counterSection state dispatch />
    <todoSection state dispatch />
    <userSection state dispatch />
  </div>
}
