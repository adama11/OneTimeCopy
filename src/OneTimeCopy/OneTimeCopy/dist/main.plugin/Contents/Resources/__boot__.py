def _reset_sys_path():
    # Clear generic sys.path[0]
    import sys
    import os

    resources = os.environ["RESOURCEPATH"]
    while sys.path[0] == resources:
        del sys.path[0]


_reset_sys_path()


def _fixup_virtualenv(real_prefix):
    import sys
    import os

    sys.real_prefix = real_prefix

    # NOTE: The adjustment code is based from logic in the site.py
    # installed by virtualenv 1.8.2 (but simplified by removing support
    # for platforms that aren't supported by py2app)

    paths = [os.path.join(sys.real_prefix, "lib", "python" + sys.version[:3])]
    hardcoded_relative_dirs = paths[:]
    plat_path = os.path.join(
        sys.real_prefix, "lib", "python" + sys.version[:3], "plat-%s" % sys.platform
    )
    if os.path.exists(plat_path):
        paths.append(plat_path)

    # This is hardcoded in the Python executable, but
    # relative to sys.prefix, so we have to fix up:
    for path in list(paths):
        tk_dir = os.path.join(path, "lib-tk")
        if os.path.exists(tk_dir):
            paths.append(tk_dir)

    # These are hardcoded in the Apple's Python executable,
    # but relative to sys.prefix, so we have to fix them up:
    hardcoded_paths = [
        os.path.join(relative_dir, module)
        for relative_dir in hardcoded_relative_dirs
        for module in ("plat-darwin", "plat-mac", "plat-mac/lib-scriptpackages")
    ]

    for path in hardcoded_paths:
        if os.path.exists(path):
            paths.append(path)

    sys.path.extend(paths)


_fixup_virtualenv('/Library/Frameworks/Python.framework/Versions/3.8')

def _site_packages(prefix, real_prefix, global_site_packages):
    import site
    import sys
    import os

    paths = []

    paths.append(
        os.path.join(prefix, "lib", "python" + sys.version[:3], "site-packages")
    )
    if os.path.join(".framework", "") in os.path.join(prefix, ""):
        home = os.environ.get("HOME")
        if home:
            paths.append(
                os.path.join(
                    home, "Library", "Python", sys.version[:3], "site-packages"
                )
            )

    # Work around for a misfeature in setuptools: easy_install.pth places
    # site-packages way to early on sys.path and that breaks py2app bundles.
    # NOTE: this is hacks into an undocumented feature of setuptools and
    # might stop to work without warning.
    sys.__egginsert = len(sys.path)

    for path in paths:
        site.addsitedir(path)

    # Ensure that the global site packages get placed on sys.path after
    # the site packages from the virtual environment (this functionality
    # is also in virtualenv)
    sys.__egginsert = len(sys.path)

    if global_site_packages:
        site.addsitedir(
            os.path.join(
                real_prefix, "lib", "python" + sys.version[:3], "site-packages"
            )
        )


_site_packages('/Users/adamdama/.local/share/virtualenvs/OneTimeCopy-nA9Dejbh/bin/..', '/Library/Frameworks/Python.framework/Versions/3.8', 0)

def _setup_ctypes():
    from ctypes.macholib import dyld
    import os

    frameworks = os.path.join(os.environ["RESOURCEPATH"], "..", "Frameworks")
    dyld.DEFAULT_FRAMEWORK_FALLBACK.insert(0, frameworks)
    dyld.DEFAULT_LIBRARY_FALLBACK.insert(0, frameworks)


_setup_ctypes()


def _path_inject(paths):
    import sys

    sys.path[:0] = paths


_path_inject(['/Users/adamdama/Downloads/OneTimeCopy'])


import re
import sys

cookie_re = re.compile(br"coding[:=]\s*([-\w.]+)")
if sys.version_info[0] == 2:
    default_encoding = "ascii"
else:
    default_encoding = "utf-8"


def guess_encoding(fp):
    for _i in range(2):
        ln = fp.readline()

        m = cookie_re.search(ln)
        if m is not None:
            return m.group(1).decode("ascii")

    return default_encoding


def _run():
    global __file__
    import os
    import site  # noqa: F401

    sys.frozen = "macosx_plugin"
    base = os.environ["RESOURCEPATH"]

    if "ARGVZERO" in os.environ:
        argv0 = os.path.basename(os.environ["ARGVZERO"])
    else:
        argv0 = None
    script = SCRIPT_MAP.get(argv0, DEFAULT_SCRIPT)  # noqa: F821

    sys.argv[0] = __file__ = path = os.path.join(base, script)
    if sys.version_info[0] == 2:
        with open(path, "rU") as fp:
            source = fp.read() + "\n"
    else:
        with open(path, "rb") as fp:
            encoding = guess_encoding(fp)

        with open(path, "r", encoding=encoding) as fp:
            source = fp.read() + "\n"

        BOM = b"\xef\xbb\xbf".decode("utf-8")

        if source.startswith(BOM):
            source = source[1:]

    exec(compile(source, script, "exec"), globals(), globals())


DEFAULT_SCRIPT='/Users/adamdama/Downloads/OneTimeCopy/main.py'
SCRIPT_MAP={}
try:
    _run()
except KeyboardInterrupt:
    pass
