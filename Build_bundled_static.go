//go:build static && !system_libgit2
// +build static,!system_libgit2

package git

/*
#cgo windows CFLAGS: -I${SRCDIR}/static-build/install/include/
#cgo windows LDFLAGS: -L${SRCDIR}/static-build/install/lib/ -lgit2 -lws2_32 -lsecur32
#cgo !windows pkg-config: --static ${SRCDIR}/static-build/install/lib/pkgconfig/libgit2.pc
#cgo CFLAGS: -DLIBGIT2_STATIC
#include <git2.h>
*/
import "C"
