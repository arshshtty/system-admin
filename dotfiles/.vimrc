" .vimrc - Vim configuration file
" Sensible defaults for development and system administration

"============================================================================
" General Settings
"============================================================================

set nocompatible              " Use Vim defaults (not Vi)
filetype plugin indent on     " Enable file type detection and plugins
syntax on                     " Enable syntax highlighting

" Character encoding
set encoding=utf-8
set fileencoding=utf-8

" Disable backup and swap files (use version control instead)
set nobackup
set nowritebackup
set noswapfile

" Persistent undo (Vim 7.3+)
if has('persistent_undo')
    set undofile
    set undodir=~/.vim/undo
    " Create undo directory if it doesn't exist
    if !isdirectory(&undodir)
        call mkdir(&undodir, 'p', 0700)
    endif
endif

"============================================================================
" User Interface
"============================================================================

set number                    " Show line numbers
set relativenumber            " Show relative line numbers
set ruler                     " Show cursor position
set showcmd                   " Show command in status line
set showmode                  " Show current mode
set wildmenu                  " Enhanced command-line completion
set wildmode=longest:full,full
set laststatus=2              " Always show status line
set cursorline                " Highlight current line
set scrolloff=5               " Keep 5 lines above/below cursor
set sidescrolloff=5           " Keep 5 columns left/right of cursor
set display+=lastline         " Show as much of last line as possible
set colorcolumn=80,120        " Show column guides at 80 and 120 characters

" Show invisible characters
set list
set listchars=tab:▸\ ,trail:·,extends:>,precedes:<,nbsp:+

" Better split opening
set splitbelow                " Open horizontal splits below
set splitright                " Open vertical splits to the right

" Mouse support
set mouse=a                   " Enable mouse in all modes

"============================================================================
" Searching
"============================================================================

set incsearch                 " Incremental search
set hlsearch                  " Highlight search results
set ignorecase                " Case-insensitive search
set smartcase                 " Case-sensitive if uppercase present
set wrapscan                  " Wrap search at EOF

" Clear search highlighting with <Esc>
nnoremap <silent> <Esc> :nohlsearch<CR><Esc>

"============================================================================
" Indentation and Formatting
"============================================================================

set autoindent                " Copy indent from current line
set smartindent               " Smart autoindenting on new line
set expandtab                 " Use spaces instead of tabs
set tabstop=4                 " Number of spaces per tab
set shiftwidth=4              " Number of spaces for auto-indent
set softtabstop=4             " Number of spaces for <Tab> key
set smarttab                  " Smart tab handling

" Language-specific indentation
autocmd FileType python setlocal ts=4 sw=4 sts=4 et
autocmd FileType javascript,typescript,json setlocal ts=2 sw=2 sts=2 et
autocmd FileType html,css,scss setlocal ts=2 sw=2 sts=2 et
autocmd FileType yaml,yml setlocal ts=2 sw=2 sts=2 et
autocmd FileType sh,bash,zsh setlocal ts=2 sw=2 sts=2 et
autocmd FileType go setlocal ts=4 sw=4 sts=4 noet

" Trim trailing whitespace on save
autocmd BufWritePre * :%s/\s\+$//e

"============================================================================
" Key Mappings
"============================================================================

" Set leader key to space
let mapleader = " "

" Save file
nnoremap <leader>w :w<CR>

" Quit
nnoremap <leader>q :q<CR>

" Save and quit
nnoremap <leader>x :x<CR>

" Force quit without saving
nnoremap <leader>Q :q!<CR>

" Move between windows
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

" Resize windows
nnoremap <C-Up> :resize +2<CR>
nnoremap <C-Down> :resize -2<CR>
nnoremap <C-Left> :vertical resize -2<CR>
nnoremap <C-Right> :vertical resize +2<CR>

" Move lines up/down
nnoremap <A-j> :m .+1<CR>==
nnoremap <A-k> :m .-2<CR>==
vnoremap <A-j> :m '>+1<CR>gv=gv
vnoremap <A-k> :m '<-2<CR>gv=gv

" Better indenting in visual mode
vnoremap < <gv
vnoremap > >gv

" Copy to system clipboard
vnoremap <leader>y "+y
nnoremap <leader>Y "+yg_
nnoremap <leader>y "+y

" Paste from system clipboard
nnoremap <leader>p "+p
nnoremap <leader>P "+P
vnoremap <leader>p "+p
vnoremap <leader>P "+P

" Select all
nnoremap <leader>a ggVG

" Toggle line numbers
nnoremap <leader>n :set number! relativenumber!<CR>

" Toggle paste mode
nnoremap <leader>pp :set paste!<CR>

" Open file explorer
nnoremap <leader>e :Explore<CR>

" Buffer navigation
nnoremap <leader>bn :bnext<CR>
nnoremap <leader>bp :bprevious<CR>
nnoremap <leader>bd :bdelete<CR>
nnoremap <leader>bl :buffers<CR>

" Tab navigation
nnoremap <leader>tn :tabnew<CR>
nnoremap <leader>tc :tabclose<CR>
nnoremap <leader>to :tabonly<CR>

"============================================================================
" File Type Specific
"============================================================================

" Markdown settings
autocmd FileType markdown setlocal spell spelllang=en_us
autocmd FileType markdown setlocal wrap linebreak

" Git commit messages
autocmd FileType gitcommit setlocal spell spelllang=en_us
autocmd FileType gitcommit setlocal textwidth=72

" Make files executable if they start with shebang
autocmd BufWritePost * if getline(1) =~ "^#!/bin/" | silent execute "!chmod +x <afile>" | endif

"============================================================================
" Netrw (Built-in File Explorer) Settings
"============================================================================

let g:netrw_banner = 0        " Disable banner
let g:netrw_liststyle = 3     " Tree view
let g:netrw_browse_split = 4  " Open in previous window
let g:netrw_altv = 1          " Open splits to the right
let g:netrw_winsize = 25      " 25% width

"============================================================================
" Colors and Appearance
"============================================================================

" Enable 256 colors
if $TERM == "xterm-256color" || $TERM == "screen-256color" || $COLORTERM == "gnome-terminal"
    set t_Co=256
endif

" Enable true colors if available
if has('termguicolors')
    set termguicolors
endif

" Set colorscheme (use default if none installed)
try
    colorscheme desert
catch
    colorscheme default
endtry

" Highlight current line number differently
highlight CursorLineNr ctermfg=yellow cterm=bold

"============================================================================
" Performance
"============================================================================

set lazyredraw                " Don't redraw during macros
set ttyfast                   " Faster terminal connection
set updatetime=300            " Faster completion (default: 4000ms)
set timeoutlen=500            " Faster key sequence completion

"============================================================================
" Miscellaneous
"============================================================================

" Return to last edit position when opening files
autocmd BufReadPost *
    \ if line("'\"") > 0 && line("'\"") <= line("$") |
    \   exe "normal! g`\"" |
    \ endif

" Automatically reload file if changed outside vim
set autoread
autocmd FocusGained,BufEnter * checktime

" Command to format JSON
command! FormatJSON %!python3 -m json.tool

" Command to remove trailing whitespace
command! TrimWhitespace :%s/\s\+$//e

" Command to convert tabs to spaces
command! TabsToSpaces :%s/\t/    /g

" Command to convert spaces to tabs
command! SpacesToTabs :%s/    /\t/g

"============================================================================
" Status Line
"============================================================================

set statusline=
set statusline+=%#PmenuSel#
set statusline+=\ %f
set statusline+=\ %#LineNr#
set statusline+=\ %m
set statusline+=%=
set statusline+=\ %#CursorColumn#
set statusline+=\ %y
set statusline+=\ %{&fileencoding?&fileencoding:&encoding}
set statusline+=\[%{&fileformat}\]
set statusline+=\ %p%%
set statusline+=\ %l:%c
set statusline+=\

"============================================================================
" Local Overrides
"============================================================================

" Source local vimrc if it exists
if filereadable(expand("~/.vimrc.local"))
    source ~/.vimrc.local
endif
