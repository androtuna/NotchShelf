# Contributing to NotchShelf

Thank you for your interest in contributing to NotchShelf!

## Development Workflow

1. **Fork and Clone** the repository:
   ```bash
   git clone https://github.com/your-username/NotchShelf.git
   cd NotchShelf
   ```

2. **Install Dependencies**:
   - macOS 14.0+ with Xcode 15+
   - [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

3. **Generate Project**:
   ```bash
   make project
   ```

4. **Run Tests**:
   Before making changes, verify that existing tests pass:
   ```bash
   make test
   ```

5. **Make Changes**:
   - Write clean Swift code adhering to modern Swift conventions.
   - If adding user-facing text, ensure keys are added to `Localizable.xcstrings` for both English and Turkish.
   - Add unit tests for new business logic or networking models.

6. **Submit a Pull Request**:
   - Open a PR against the `main` branch with a clear description of the problem solved or feature implemented.
