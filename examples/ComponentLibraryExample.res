// SPDX-License-Identifier: PMPL-1.0-or-later
// Component library example — demonstrates composable, reusable components

// Button component
module Button = {
  type variant = Primary | Secondary | Danger

  @react.component
  let make = (~variant=Primary, ~label: string, ~onClick=?) => {
    let className = switch variant {
    | Primary => "btn btn-primary"
    | Secondary => "btn btn-secondary"
    | Danger => "btn btn-danger"
    }

    <button className ?onClick>
      {label |> React.string}
    </button>
  }
}

// Card component
module Card = {
  @react.component
  let make = (~title: string, ~children) => {
    <div className="card">
      <div className="card-header">
        <h3> {title |> React.string} </h3>
      </div>
      <div className="card-body">
        {children}
      </div>
    </div>
  }
}

// Badge component
module Badge = {
  type color = Blue | Green | Red | Yellow

  @react.component
  let make = (~color=Blue, ~text: string) => {
    let className = switch color {
    | Blue => "badge badge-blue"
    | Green => "badge badge-green"
    | Red => "badge badge-red"
    | Yellow => "badge badge-yellow"
    }

    <span className>
      {text |> React.string}
    </span>
  }
}

// Alert component
module Alert = {
  type level = Info | Success | Warning | Error

  @react.component
  let make = (~level=Info, ~message: string, ~onClose=?) => {
    let className = switch level {
    | Info => "alert alert-info"
    | Success => "alert alert-success"
    | Warning => "alert alert-warning"
    | Error => "alert alert-error"
    }

    <div className>
      <p> {message |> React.string} </p>
      {switch onClose {
      | Some(handler) =>
        <button onClick={_ => handler()}>
          {"Dismiss" |> React.string}
        </button>
      | None => React.null
      }}
    </div>
  }
}

// Example usage
@react.component
let make = () => {
  let (alerts, setAlerts) = React.useState(_ => list{})

  let addAlert = () => {
    setAlerts(prev => list{`Alert at ${Js.Date.now()->Int.fromFloat->Int.toString}`, ...prev})
  }

  let dismissAlert = (index: int) => {
    setAlerts(prev => prev |> List.filteri((i, _) => i != index))
  }

  <div className="component-library-demo">
    <Card title="Components Library">
      <div className="demo-section">
        <h4> {"Buttons" |> React.string} </h4>
        <Button label="Primary" variant=Button.Primary />
        <Button label="Secondary" variant=Button.Secondary />
        <Button label="Danger" variant=Button.Danger onClick={_ => addAlert()} />
      </div>

      <div className="demo-section">
        <h4> {"Badges" |> React.string} </h4>
        <Badge text="Blue" color=Badge.Blue />
        <Badge text="Green" color=Badge.Green />
        <Badge text="Red" color=Badge.Red />
        <Badge text="Yellow" color=Badge.Yellow />
      </div>

      <div className="demo-section">
        <h4> {"Alerts" |> React.string} </h4>
        {alerts
          |> List.mapi((i, msg) =>
            <Alert key={Int.toString(i)} level=Alert.Info message={msg} onClose={() => dismissAlert(i)} />
          )
          |> Array.of_list
          |> React.array}
      </div>
    </Card>
  </div>
}
