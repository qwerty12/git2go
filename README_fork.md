# Overview

This fork is targeted at being built in a MSYS2 CLANG64 Windows environment, with the expectation that libgit2 will be statically linked into your Go application.

---

# Breaking Changes

### Indexer API

With the libgit2 update to 1.9, `git_indexer_hash` is deprecated. The suggested replacement, if not equivalent, is `git_indexer_name`. With that in mind, the `Commit` method on `Indexer` has changed:

```go
// Old:
func (indexer *Indexer) Commit() (*Oid, error)

// New:
func (indexer *Indexer) Commit() (string, error)
```

### Go Module Version

The required Go version was increased:

* `go.mod`: **1.13 → 1.25**

### Threading

This fork builds a **non-threadsafe** libgit2 by default.
Edit build-libgit2-static.sh and change to `USE_THREADS="ON"` for a thread-safe libgit2 build.

### Explicit libgit2 Initialization

`libgit2` is **not initialized automatically**.
Before using git2go's methods, your application must call once:

```go
git.InitLibGit2(&git.InitOptions{})
```

### `runtime.LockOSThread()` calls in wrapper removed if libgit2 is non-threadsafe

If the libgit2 git2go is using is built with `USE_THREADS=OFF` (i.e. a non-threadsafe build),
then the wrappers in git2go won't call `LockOSThread()` for you. You should do this yourself.

---

# Building libgit2 on MSYS2 CLANG64

1. Install [MSYS2](https://www.msys2.org/)

   When the installer finishes, **untick “Run MSYS2 now”.**

2. Launch **MSYS2 CLANG64** from the Start Menu

3. Run:

   ```
   pacman -Syu
   ```

   Repeat until everything is fully updated.

4. Install the required packages:

   ```
   pacman -S --needed mingw-w64-clang-x86_64-clang mingw-w64-clang-x86_64-cmake make
   ```

5. `cd` into your recursive clone of this repository

6. Build:

   ```
   USE_CHROMIUM_ZLIB=ON ./script/build-libgit2-static.sh
   ```

   Notes:

   * `USE_CHROMIUM_ZLIB=ON` adds `-march=native` to CFLAGS.
     Remove this if you intend to ship binaries for other machines.

---

# Linking your program against this

In general, [the *`main` branch, or vendored static linking* section from the proper README](README.md#main-branch-or-vendored-static-linking) is worth reading.

This assumes your project’s `go.mod` has a `replace` directive pointing to a clone of this repo where [libgit2 has already been built](#building-libgit2-on-msys2-clang64).

### Using `march=native` with CGO for consistency

If you built libgit2 with `USE_CHROMIUM_ZLIB=ON`, you might want to make sure CGO builds its code with `march=native` too:  

```
set "CGO_CFLAGS=-O3 -march=native -fomit-frame-pointer"
```

### Building outside MSYS2 CLANG64

To enable building your program outside of the MSYS2 CLANG64 environment, tell Go where to find the C compiler:

```
set "CC=C:\msys64\clang64\bin\clang.exe"
```

### Statically linking git2go

Finally, all that is required is adding

```
-tags static
```

to your `go build` / `go install` etc. invocations.