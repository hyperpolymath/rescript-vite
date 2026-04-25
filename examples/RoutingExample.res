// SPDX-License-Identifier: PMPL-1.0-or-later
// Simple hash-based routing example — demonstrates client-side routing without external libraries

type route =
  | Home
  | About
  | Contact
  | NotFound

let routeFromHash = (hash: string): route => {
  switch hash {
  | "" | "#/" => Home
  | "#/about" => About
  | "#/contact" => Contact
  | _ => NotFound
  }
}

let getHash = (): string => {
  let hash = %raw(`window.location.hash`)
  hash
}

// Home page
@react.component
let homePage = () => {
  <div className="page">
    <h1> {"Welcome to rescript-vite" |> React.string} </h1>
    <p>
      {"This is a simple hash-based routing example. Click the links above to navigate."
        |> React.string}
    </p>
  </div>
}

// About page
@react.component
let aboutPage = () => {
  <div className="page">
    <h1> {"About Us" |> React.string} </h1>
    <p> {"Learn more about this project and its goals." |> React.string} </p>
    <ul>
      <li> {"Built with ReScript + Vite" |> React.string} </li>
      <li> {"Type-safe frontend development" |> React.string} </li>
      <li> {"Zero-config bundling" |> React.string} </li>
    </ul>
  </div>
}

// Contact page
@react.component
let contactPage = () => {
  <div className="page">
    <h1> {"Contact Us" |> React.string} </h1>
    <p> {"Send us a message using the form below." |> React.string} </p>
    <form>
      <input type_="email" placeholder="Your email" />
      <textarea placeholder="Your message" />
      <button type_="submit"> {"Send" |> React.string} </button>
    </form>
  </div>
}

// Not found page
@react.component
let notFoundPage = () => {
  <div className="page">
    <h1> {"404 - Page Not Found" |> React.string} </h1>
    <p> {"The page you're looking for doesn't exist." |> React.string} </p>
  </div>
}

// Main router component
@react.component
let make = () => {
  let (hash, setHash) = React.useState(_ => getHash())

  React.useEffect0(() => {
    let handleHashChange = () => {
      setHash(_ => getHash())
    }

    let window = %raw(`window`)
    window["addEventListener"]("hashchange", handleHashChange)

    Some(
      () => {
        window["removeEventListener"]("hashchange", handleHashChange)
      }
    )
  })

  let route = routeFromHash(hash)

  <div className="router-app">
    <nav className="nav">
      <a href="#/"> {"Home" |> React.string} </a>
      <a href="#/about"> {"About" |> React.string} </a>
      <a href="#/contact"> {"Contact" |> React.string} </a>
    </nav>

    <div className="content">
      {switch route {
      | Home => <homePage />
      | About => <aboutPage />
      | Contact => <contactPage />
      | NotFound => <notFoundPage />
      }}
    </div>
  </div>
}
