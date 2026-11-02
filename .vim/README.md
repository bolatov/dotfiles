# .vim

Installation
============

`git clone <repo>`, then `cd ~ && ln -s <path/to/dotfiles> .vim`.
the `vimrc` file is loaded when Vim starts.  To see the order in which configuration files are read, run vim --version.

You may also want to link to the inputrc file to get a compatible readline setup `ln -s dotvim/inputrc .inputrc`.

## Tips and Tricks

- Format JSON by `%!jq`
- Refresh NerdTree view by `R`

## References
- [Vim Packages][1]


[1]: https://learnvim.irian.to/customize/vim_packages
