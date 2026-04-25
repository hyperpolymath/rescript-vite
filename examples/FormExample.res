// SPDX-License-Identifier: PMPL-1.0-or-later
// Form example with validation — demonstrates type-safe form handling

type formState = {
  name: string,
  email: string,
  message: string,
}

type validation = {
  nameError: option<string>,
  emailError: option<string>,
  messageError: option<string>,
}

let validateEmail = (email: string): bool => {
  // Simple email validation (use a proper library in production)
  String.includes(email, "@") && String.includes(email, ".")
}

let validate = (form: formState): validation => {
  nameError: if String.length(form.name) < 2 {
    Some("Name must be at least 2 characters")
  } else {
    None
  },
  emailError: if !validateEmail(form.email) {
    Some("Please enter a valid email address")
  } else {
    None
  },
  messageError: if String.length(form.message) < 10 {
    Some("Message must be at least 10 characters")
  } else {
    None
  },
}

@react.component
let make = () => {
  let (form, setForm) = React.useState(_ => {
    name: "",
    email: "",
    message: "",
  })

  let (errors, setErrors) = React.useState(_ => {
    nameError: None,
    emailError: None,
    messageError: None,
  })

  let (submitted, setSubmitted) = React.useState(_ => false)

  let handleChange = (field: string, value: string) => {
    let updated = switch field {
    | "name" => {...form, name: value}
    | "email" => {...form, email: value}
    | "message" => {...form, message: value}
    | _ => form
    }
    setForm(_ => updated)
  }

  let handleSubmit = (e: React.Synthetic.Form.t) => {
    ReactEvent.Form.preventDefault(e)
    let validation = validate(form)
    setErrors(_ => validation)
    let isValid = validation.nameError == None && validation.emailError == None && validation.messageError == None
    if isValid {
      setSubmitted(_ => true)
      // Submit form data here
      Js.Console.log2("Form submitted:", form)
    }
  }

  <form onSubmit={handleSubmit} className="contact-form">
    <div className="form-group">
      <label htmlFor="name"> {"Name" |> React.string} </label>
      <input
        id="name"
        type_="text"
        value={form.name}
        onChange={e => handleChange("name", ReactEvent.Form.target(e)["value"])}
        className={errors.nameError != None ? "input-error" : ""}
      />
      {switch errors.nameError {
      | Some(err) => <span className="error"> {err |> React.string} </span>
      | None => React.null
      }}
    </div>

    <div className="form-group">
      <label htmlFor="email"> {"Email" |> React.string} </label>
      <input
        id="email"
        type_="email"
        value={form.email}
        onChange={e => handleChange("email", ReactEvent.Form.target(e)["value"])}
        className={errors.emailError != None ? "input-error" : ""}
      />
      {switch errors.emailError {
      | Some(err) => <span className="error"> {err |> React.string} </span>
      | None => React.null
      }}
    </div>

    <div className="form-group">
      <label htmlFor="message"> {"Message" |> React.string} </label>
      <textarea
        id="message"
        value={form.message}
        onChange={e => handleChange("message", ReactEvent.Form.target(e)["value"])}
        className={errors.messageError != None ? "input-error" : ""}
      />
      {switch errors.messageError {
      | Some(err) => <span className="error"> {err |> React.string} </span>
      | None => React.null
      }}
    </div>

    <button type_="submit"> {"Submit" |> React.string} </button>

    {submitted ? <div className="success"> {"Form submitted successfully!" |> React.string} </div> : React.null}
  </form>
}
