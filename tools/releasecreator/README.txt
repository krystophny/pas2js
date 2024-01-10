Pas2jsReleaseCreator is a tool to create a release or a snapshot of pas2js.

It creates a zip for a binary distribution of pasj2s:
- binaries, e.g. pas2js.exe and some tools like compileserver.exe
- demos
- packages
- It does not include the compiler sources.

The creator requires some installed tools: git, make, zip, fpc release version,
and fpc devel version.

Running:

./Pas2jsReleaseCreator -s ../.. --fpcrelease=/usr/lib/fpc/3.2.2/ppcx64 --fpcdevel=/usr/lib/fpc/3.3.1/ppcx64 -x

You can put some parameters into an ini file and pass that via -c.
Example for an ini file:

[Main]
fpcrelease=/usr/lib/fpc/3.2.2/ppcx64
fpcdevel=/usr/lib/fpc/3.3.1/ppcx64
sourcedir=../..

