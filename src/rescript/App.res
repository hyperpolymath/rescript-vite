// SPDX-License-Identifier: PMPL-1.0-or-later
// Main ReScript application component
// Demonstrates type-safe ReScript + React integration with Vite

@react.component
let make = () => {
  let (count, setCount) = React.useState(_ => 0)

  <div className="app">
    <header className="app-header">
      <h1> {"ReScript + Vite" |> React.string} </h1>
      <p> {"Type-safe frontend development" |> React.string} </p>
    </header>

    <main>
      <div className="counter">
        <p> {"Current count: " ++ Int.toString(count) |> React.string} </p>
        <button onClick={_ => setCount(x => x + 1)}>
          {"+1" |> React.string}
        </button>
        <button onClick={_ => setCount(x => x - 1)}>
          {"-1" |> React.string}
        </button>
      </div>

      <section className="docs">
        <h2> {"Getting Started" |> React.string} </h2>
        <ul>
          <li> {"Edit src/rescript/App.res and save to see hot module replacement" |> React.string} </li>
          <li> {"ReScript compiles to JavaScript; Vite handles the bundling" |> React.string} </li>
          <li> {"Type safety is checked at compile-time" |> React.string} </li>
        </ul>
      </section>
    </main>
  </div>
}
