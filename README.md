# Openplanet Plugin Template

This template includes a build script that will help you develop plugins.

**Important:**, the plugin will be built by copying all files from `./src/*` to the destination, along with `info.toml` and the readme + license.
This means that exports should not be prefixed with `src/`, and any files within `src` can be referenced, similarly, without a `src/` prefix.
The reason for this is so that you can store other files in the repo for this plugin (such as assets, fonts, manialink scripts, etc).
If you need to build resources while building the plugin, the build scripts are fairly straightforward and you're encouraged to mess around with them.
They all work pretty much the same.

## Usage

### Template Preparation

* Clone this repo, or download the zip and extract it.
* Delete `.git` if need be.
* Based on your preferred build system (python, powershell, or bash under WSL), remove the other build scripts. The idea is that you can customize the build script to suit your needs down the line, so best to pick one and stick with it.
* (Optional) Customize the template in `src`, remove the `advanced_dev` directory if you're never going to use it, change the license to your favorite one, etc.

### Template Usage

I use the template like this:

```
$ cd ~/src/openplanet
$ cp -a template tm-my-new-plugin
$ code tm-my-new-plugin  # to open vscode
```

After copying:

* Update info.toml with plugin name, author, version, etc
* Update README.md (and LICENSE if you haven't and want to)
* Remove unneeded .as files

### Notes

* In info.toml, there's a line like `#__DEFINES__`; this will be replaced by the build script to enable use of preprocessor statements like `#if UNITTEST` or `#if DEV`.

## Build Scripts

- Required: 7zip (you need the `7z` executable in your PATH)

The python build script supports both windows and WSL. (Python3, at least somewhat recent like 3.7+ or something)

### Linux

- Have `$HOME/OpenplanetNext` symlinked to your `OpenplanetNext` directory
- `dos2unix` is required

-----

License: Public Domain

Authors: XertroV

Suggestions/feedback: @XertroV on Openplanet discord

Code/issues: [https://github.com/XertroV/tm-openplanet-plugin-template](https://github.com/XertroV/tm-openplanet-plugin-template)

GL HF
