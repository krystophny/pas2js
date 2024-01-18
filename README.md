## Welcome to pas2js

Pas2js is an open source Pascal to JavaScript transpiler.
It parses Object Pascal and emits JavaScript.

Official site:
[http://wiki.freepascal.org/pas2js](http://wiki.freepascal.org/pas2js)


## Directories

* **packages** - source files needed to compile pas2js programs
* **demo** - examples
* **bin** - output folder for binaries, e.g. pas2js.exe
* **compiler** - source files to compile the compiler. This is an external submodule link.
* **units** - output folder of compiler ppu/o files
* **utils** - utilities

## Building

### Compiler
You need to install the Free Pascal compiler (fpc), 3.2.0 or better, 32 or 64bit.
Either from their website
```text
https://www.freepascal.org/download.html
```
Or via Lazarus
```text
http://wiki.freepascal.org/Getting_Lazarus
```

Or on MacOS via homebrew. On Linux this can be done via your package manager
as well if it has the latest version.

### building pas2js

### Complete checkout

The makefile expects the sources of FPC to be present under the `compiler` directory.
You can copy/clone the FPC sources there. Note that a symlink to the FPC sources will not work, as the linker confuses some relative paths.

For example:

```sh
git clone https://gitlab.com/freepascal.org/fpc/pas2js.git pas2js
cd pas2js
git config --local pull.rebase true
git clone https://gitlab.com/freepascal.org/fpc/source.git compiler
cd compiler
git config --local pull.rebase true
```

```sh
Update aka fetch new:
cd pas2js
git pull
cd compiler
git pull
```

This will pull any upstream changes to your local FPC repository.

#### Building on Linux/macOS
type the following command:
```sh
make all
```

This creates with a 64-bit fpc the executable `bin/x86_64-linux/pas2js`
and a basic config file `bin/x86_64-linux/pas2js.cfg`.


#### Building on Windows


Make sure that you use the `make.exe` from fpc, not the one from Delphi by setting the
`PATH`: For example if you installed the 32-bit version of fpc in
`C:\YourPathOfFPC\3.2.2`:
```bat
set PATH=C:\YourPathOfFPC\3.2.2\bin\i386-win32;%PATH%
```
If you installed the 64-bit version of fpc in `C:\YourPathOfFPC\3.2.2` use
```bat
set PATH=C:\YourPathOfFPC\3.2.2\bin\x86-64-win64;%PATH%
```
Then compile
make all

If you see "Error makefile ... Command syntax error" your "set PATH" was
not correct.

When `make all` has succesfully finished it created with a 32-bit fpc the executable
`bin/i386-win32/pas2js.exe` and a basic config file
`bin/i386-win32/pas2js.cfg`.


## Configuration

pas2js requires unit search paths (-Fu) in order to find its rtl units and
rtl.js. Building and installing should have created a default pas2js.cfg
containing those parameters.

[http://wiki.freepascal.org/pas2js.cfg]([http://wiki.freepascal.org/pas2js.cfg])


