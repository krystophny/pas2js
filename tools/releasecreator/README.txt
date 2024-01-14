Pas2jsReleaseCreator is a tool to create a release or a snapshot of pas2js.

It creates a zip for a binary distribution of pasj2s:
- Fetch version from Pascal sources and check version in rtl.js
- Compile a bunch of executables:
  - pas2js using fpc release
  - libpas2js using fpc release and optional a second with fpc devel
  - compileserver with fpc devel
  - webidl2pas with fpc devel
  - makestub with fpc devel
- Copy files:
  - demo
  - packages
  - tools except for releasecreator
  - rtl.js
  - It does not include the compiler sources.
- Compile createconfig and create pas2js.cfg
- Create a zip

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

