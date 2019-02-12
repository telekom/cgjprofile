# cgjprofile

Command Line Tool for macOS to analyse the validity of mobile provision files and the corresponding certificates. The software is well suited to be used in automated setups.

Let me know if this is useful, I am looking forward to your comments!

## Building

This is a Swift Package Manager project. To build, simply execute `swift build -c release`. To create an Xcode project for debugging, execute `swift package generate-xcodeproj`.

For more information, see the [Package Manager documentation](https://swift.org/package-manager/)

## Usage

Once built, the tool can be invoked like this:

`cgjprofile [--format="format string"] [--warn-expiration days] [--quiet] [path]`

### The Format String

The format string takes c-style placeholders:

* %e ExpirationDate
* %c CreationDate
* %u UUID
* %a AppIDName
* %t TeamName
* %n Name

Minimum width specifiers can be used, such as "%40u", adding spaces until the minimum length is met.

If no format string is provided, the default is "%u %t %n"

### Expiration Warning

If provided, a warning will be given if the profile will expire in the given number of days

### Quiet

What you expect it would do. No output other than errors and the return value

### Path

If provided, the path to the profile to be checked. Otherwise, all installed profiles are checked.

### Return Value

* 0 on success
* 1 if any profile was invalid

