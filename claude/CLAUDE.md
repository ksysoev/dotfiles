Go Code Style Rules
This document outlines the code style rules and best practices that should be followed when generating Go code for this project.


Go Proverbs:
1. Clear is better than clever
  - Write straightforward, readable code
  - Avoid complex one-liners or obscure optimizations
  - Prioritize clarity over brevity
  - Make the zero value useful
2. Design structs so their zero values are ready to use
  - Avoid unnecessary initialization checks
  - Don't add flags like initialized bool where possible
  - interface{} says nothing
3. Avoid empty interfaces (interface{}) when possible
  - Define specific interfaces with meaningful methods
  - Use generics for type-parametric code in Go 1.18+
  - Accept interfaces, return structs
4. Functions should accept interfaces for flexibility
  - Return concrete types for clarity and usability
  - This promotes better decoupling and testability
5. Don't panic
  - Return errors explicitly rather than using panic
  - Use panic only for truly unrecoverable situations
  - Implement proper error handling and propagation

SOLID Principles:
1. Single Responsibility Principle
  - Each type should have only one reason to change
  - Separate concerns into different types
  - Keep interfaces focused and cohesive
2. Open-Closed Principle
  - Code should be open for extension but closed for modification
  - Use interfaces and composition instead of type switches
  - Avoid modification patterns that require changing existing code
  - Interface Segregation Principle
3. Create small, focused interfaces
  - Clients should not depend on methods they don't use
  - Compose interfaces when needed
  - Dependency Inversion Principle
4. Depend on abstractions, not concrete implementations
  - High-level modules should not depend on low-level modules
  - Use dependency injection to provide implementations

Error Handling:
1. Custom error types
  - Create specific error types for different error cases
  - Implement the Error() method properly
  - Use constructor functions for creating errors
2. Error wrapping
  - Use fmt.Errorf("context: %w", err) to add context to errors
  - Preserve the original error for proper error checking
  - Add meaningful context at each level
3. Error logging
  - Only log errors if handling them (not returning them)
  - Use slog for structured logging
  - Include relevant context in error logs

Documentation:

1. Function documentation
  - Document all exported functions
  - Follow standard comment format (// FuncName does...)
  - Explain parameters, return values, and errors
2. Package documentation
  - Add package-level documentation at the top of a file
  - Describe the package's purpose and core functionality
  - Provide usage examples for complex packages
  - Interface documentation
3. Document each interface and its methods
  - Explain the contract of the interface
  - Note any special behaviors or requirements

Testing:

1. Use testify for assertions
  - All tests should use the testify package
  - Use assert.* functions for assertions
  - Keep assertions clear and readable
2. Table-driven tests
  - Organize test cases in slices of struct
  - Name each test case
  - Test multiple scenarios in a single test function

Mocking:

1. Use mockery for generating mocks
2. Configure mockery in .mockery.yaml
3. Use EXPECT() for setting expectations


Project Structure:

1. Executable files
  - Place main.go in cmd/example-app/main.go
  - Keep main.go simple - only initialization and startup
  - Delegate actual functionality to packages
  - Command Line Interface
2. Use cobra for CLI commands
  - Place CLI logic in pkg/cmd
  - Separate command handlers from business logic
3. API Server
  - Implement HTTP servers in pkg/api
  - Follow standard http package patterns
  - Handle errors and shutdowns gracefully
4. Core Package
  - Place business logic in pkg/core
  - Keep core logic independent of external dependencies
  - Use interfaces to define dependencies
5. Repository Package
  - Implement data storage in pkg/repo
  - Abstract database operations
  - Handle internal state management
6. Providers Package
  - Place external service clients in pkg/prov
  - Manage external dependencies
  - Abstract third-party APIs

Additional Requirements:

1. Before finishing any task:
  - Run golangci-lint and address all issues
  - Continue fixing issues until all linting passes
  - Fix struct field alignment issues:
2. Use fieldalignment -fix ./... to optimize struct memory layout
  - This improves memory usage and performance

Configuration:

1. Use viper for configuration management
2. Support both YAML and JSON formats
3. Allow environment variable overrides

Logging:

1. Use log/slog for structured logging
2. Support both JSON and text formats
3. Include appropriate context in log entries

Git Commits and Pull Requests:

1. Never add Claude attribution
  - No "Co-Authored-By: Claude" trailers in commit messages
  - No "Generated with Claude Code" lines in PR descriptions
  - Commits must be authored solely under the user's own git identity
