// SPDX-License-Identifier: PMPL-1.0-or-later
// API integration example — demonstrates type-safe data fetching

type user = {
  id: int,
  name: string,
  email: string,
}

type apiState =
  | Loading
  | Success(array<user>)
  | Error(string)

@val external fetch: string => Js.Promise.t<Response.t> = "fetch"

module Response = {
  @send external json: Response.t => Js.Promise.t<Js.Json.t> = "json"
}

let fetchUsers = async () => {
  try {
    let response = await fetch("https://jsonplaceholder.typicode.com/users")
    let json = await Response.json(response)
    // In a real app, you'd use a JSON decoder library (e.g., Js.Json or serde)
    Js.Console.log("API response:", json)
    Success([])
  } catch {
  | _ => Error("Failed to fetch users")
  }
}

@react.component
let make = () => {
  let (state, setState) = React.useState(_ => Loading)

  React.useEffect0(() => {
    let fetch = async () => {
      let result = await fetchUsers()
      setState(_ => result)
    }
    let _ = fetch()
    None
  })

  <div className="api-example">
    <h2> {"User List" |> React.string} </h2>
    {switch state {
    | Loading =>
      <p> {"Loading..." |> React.string} </p>
    | Success(users) =>
      <ul>
        {users
          |> Array.mapi((i, user) =>
            <li key={Int.toString(i)}>
              {`${user.name} (${user.email})` |> React.string}
            </li>
          )
          |> React.array}
      </ul>
    | Error(err) =>
      <div className="error">
        {"Error: " ++ err |> React.string}
      </div>
    }}
  </div>
}
