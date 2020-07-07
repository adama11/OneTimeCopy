from setuptools import setup

APP = ["main.py"]
OPTIONS = {
    # Any local packages to include in the bundle should go here.
    # See the py2app documentation for more
    "includes": ["nltk", "pandas", "tzlocal"],
}

setup(
    plugin=APP,
    options={"py2app": OPTIONS},
    setup_requires=["py2app"],
    install_requires=["pyobjc"],
)
