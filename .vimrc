set runtimepath+=~/.vim/bundle/neobundle.vim/ 
call neobundle#begin(expand('~/.vim/bundle/')) 
NeoBundleFetch 'Shougo/neobundle.vim' 
NeoBundle 'davidhalter/jedi-vim' 
"NeoBundle 'tpope/vim-fugitive' 
"NeoBundle 'scrooloose/nerdtree' 
NeoBundle 'ervandew/supertab'
call neobundle#end() 
NeoBundleCheck

"supertab setting
let g:SupperTabDefaultCompletionType = "context"

"jedi setting 
let g:jedi#completions_enabled = 1  

au FileType python let g:jedi#completions_enabled = 1
" no docstring
" au FileType python setlocal completeopt-=preview

" Only do this part when compiled with support for autocommands.
if has("autocmd")
    " Use filetype detection and file-based automatic indenting.
    filetype plugin indent on

    " Use actual tab chars in Makefiles.
    autocmd FileType make set tabstop=4 shiftwidth=4 softtabstop=0 noexpandtab
endif

" For everything else, use a tab width of 4 space chars.
set tabstop=4       " The width of a TAB is set to 4.
                    " Still it is a \t. It is just that
                    " Vim will interpret it to be having
                    " a width of 4.
set shiftwidth=4    " Indents will have a width of 4.
set softtabstop=4   " Sets the number of columns for a TAB.
set expandtab       " Expand TABs to spaces.
set hlsearch
set nu
set backspace=indent,eol,start

set pastetoggle=<F2>
map <F5> :w \| !pytest -qs %:p
map <F6> :w \| !git commit %:p -m "Update content" 
map <F7> :w \| !git diff %:p 
map <F10> !git push 

syntax on

execute pathogen#infect()
