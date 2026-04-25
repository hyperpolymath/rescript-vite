# Testing Guide for rescript-vite

<!-- SPDX-License-Identifier: PMPL-1.0-or-later -->

## Overview

rescript-vite uses **Vitest** for testing. Tests can be written in JavaScript or ReScript and verify both compiled ReScript code and React components.

## Test Structure

```
tests/
├── unit/               # Unit tests for pure functions
│   └── Math.test.res
├── integration/        # Integration tests for components + API
│   └── App.test.js
└── e2e/               # End-to-end tests (optional: Playwright)
```

## Unit Tests (ReScript)

Test pure functions directly in ReScript:

```rescript
// tests/unit/Math.test.res
let add = (a: int, b: int): int => a + b

let () = {
  Js.Console.assert_(add(2, 3) == 5, "2 + 3 should equal 5")
  Js.Console.assert_(add(0, 0) == 0, "0 + 0 should equal 0")
}
```

## Integration Tests (JavaScript)

Test React components and interactions using Vitest:

```javascript
// tests/integration/Counter.test.js
import { render, screen, fireEvent } from '@testing-library/react'
import Counter from '@/Counter.res.js'

describe('Counter Component', () => {
  test('renders initial count', () => {
    render(<Counter />)
    expect(screen.getByText('0')).toBeInTheDocument()
  })

  test('increments on button click', () => {
    render(<Counter />)
    const button = screen.getByText('+1')
    fireEvent.click(button)
    expect(screen.getByText('1')).toBeInTheDocument()
  })
})
```

## Running Tests

```bash
# Run all tests
npm test

# Run tests in watch mode
npm test -- --watch

# Run tests with UI
npm run test:ui

# Run tests with coverage
npm test -- --coverage
```

## Testing Patterns

### Testing Pure Functions

```rescript
// src/rescript/Utils.res
let validateEmail = (email: string): bool => {
  String.includes(email, "@") && String.includes(email, ".")
}

// tests/unit/Utils.test.res
let () = {
  Js.Console.assert_(
    validateEmail("test@example.com") == true,
    "Valid email should return true"
  )
  Js.Console.assert_(
    validateEmail("invalid") == false,
    "Invalid email should return false"
  )
}
```

### Testing React Components

```javascript
// tests/integration/Button.test.js
import { render, screen } from '@testing-library/react'
import Button from '@/Button.res.js'

describe('Button Component', () => {
  test('renders with correct label', () => {
    render(<Button label="Click me" />)
    expect(screen.getByText('Click me')).toBeInTheDocument()
  })

  test('calls onClick handler', () => {
    const onClick = vi.fn()
    const { getByText } = render(<Button label="Click" onClick={onClick} />)
    fireEvent.click(getByText('Click'))
    expect(onClick).toHaveBeenCalled()
  })
})
```

### Testing Async Code

```javascript
// tests/integration/Api.test.js
import { render, screen, waitFor } from '@testing-library/react'
import UserList from '@/UserList.res.js'

describe('UserList Component', () => {
  test('loads and displays users', async () => {
    render(<UserList />)
    
    expect(screen.getByText('Loading...')).toBeInTheDocument()
    
    await waitFor(() => {
      expect(screen.queryByText('Loading...')).not.toBeInTheDocument()
    })
    
    expect(screen.getByText(/user/i)).toBeInTheDocument()
  })
})
```

### Testing Forms

```javascript
// tests/integration/ContactForm.test.js
import { render, screen, fireEvent } from '@testing-library/react'
import ContactForm from '@/ContactForm.res.js'

describe('ContactForm Component', () => {
  test('validates email', async () => {
    render(<ContactForm />)
    
    const input = screen.getByPlaceholderText('Email')
    fireEvent.change(input, { target: { value: 'invalid' } })
    
    expect(screen.getByText(/valid email/i)).toBeInTheDocument()
  })

  test('submits form with valid data', async () => {
    const onSubmit = vi.fn()
    render(<ContactForm onSubmit={onSubmit} />)
    
    fireEvent.change(screen.getByPlaceholderText('Name'), { target: { value: 'John' } })
    fireEvent.change(screen.getByPlaceholderText('Email'), { target: { value: 'john@example.com' } })
    fireEvent.click(screen.getByText('Submit'))
    
    await waitFor(() => {
      expect(onSubmit).toHaveBeenCalled()
    })
  })
})
```

## Best Practices

1. **Test Behavior, Not Implementation** — Test what users see and interact with, not internal state
2. **Use Semantic Queries** — Prefer `getByRole`, `getByLabelText`, `getByPlaceholderText` over `getByTestId`
3. **Avoid Testing Library Details** — Don't test ReScript internals; test the React component behavior
4. **Keep Tests Focused** — One assertion per test when possible
5. **Use Fixtures** — Create reusable test data
6. **Mock External APIs** — Use `vi.fn()` to mock fetch, network calls, etc.

## Mocking

```javascript
// Mock window.fetch
global.fetch = vi.fn(() =>
  Promise.resolve({
    json: () => Promise.resolve({ id: 1, name: 'User' })
  })
)

// Mock localStorage
const localStorageMock = {
  getItem: vi.fn(),
  setItem: vi.fn(),
  removeItem: vi.fn(),
  clear: vi.fn(),
}
global.localStorage = localStorageMock
```

## Coverage

Generate coverage reports:

```bash
npm test -- --coverage
```

Coverage will be written to `coverage/` directory. Open `coverage/index.html` in a browser to view the report.

## Continuous Integration

Tests run automatically on every push via GitHub Actions (`.github/workflows/quality.yml`):

```yaml
- name: Run tests
  run: npm test
```

## Resources

- [Vitest Documentation](https://vitest.dev)
- [Testing Library](https://testing-library.com)
- [React Testing Best Practices](https://kentcdodds.com/blog/common-mistakes-with-react-testing-library)
