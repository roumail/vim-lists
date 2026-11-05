# vim-lists

The lists roumail's Vim plugins show in a window at the bottom, all opened,
filtered, redrawn and closed the same way. It has no commands of its own: a
plugin that needs it says so.

## In every list

The first line is the list's heading: its title, then its keys. One window
holds the list, so `q` and `:q` close only it; opening a list that is already
open goes to its window. The window is as tall as the list, up to
`g:roumail_lists_height` lines (default 15).

| Key | What it does |
| --- | --- |
| `dd` | Remove the item under the cursor, in the lists that can (their heading says `dd remove`). What removing means is the list's: `:Compares` forgets a comparison, `:AiCommentsList` deletes a review once you confirm. |
| `/` | Filter the list as you type (below), in the lists that say so in their heading. |
| `r` | Refresh. The cursor stays on its item; the filter stays. |
| `q` | Close (`:q` too). |

Each list adds its own keys, in its heading before these. `dd` is the key
quickfix windows remove an entry with too (with
[qf-tools](https://github.com/roumail/qf-tools)), so it is the same in every
list at the bottom.

### Filtering with `/`

`/` starts a filter: what you type shows at the bottom as `/words`, and the
list narrows with each key to what matches it. It matches fuzzily, as fzf
does: `fix login` keeps what both words match, its letters in order but not
necessarily together. What it matches on is the list's to say. While you type:

| Key | What it does |
| --- | --- |
| `<CR>` | Stop typing and keep the filter. The list stays narrowed and its keys work on it. |
| `<Esc>` or `<C-c>` | Stop typing and drop what you changed: back to the filter you had before pressing `/` (none, the first time). |
| `<BS>` | Delete the last character. |
| `<C-w>` | Delete the last word. |
| `<C-u>` | Delete the whole filter, so everything shows again. You are still typing: `<CR>` leaves the list unfiltered. |

While a filter is kept, the heading says how many match, and the filter, as
`Open PRs (20), 3 matching 'login'`. To remove it, `/`, `<C-u>`, `<CR>`; to
change it, `/` and type on from where it was.

## For a plugin

```vim
call roumail_lists#open('myplugin://things/' . name, {
      \ 'fetch': function('s:fetch'),       " the items, or v:null when it failed
      \ 'heading': function('s:heading'),   " (items) -> lines, the first the title
      \ 'rows': function('s:rows'),         " (items) -> [{'lines': [...], 'item': item}, ...]
      \ 'id': {item -> item.name},          " the same for an item across fetches
      \ 'match': {item -> item.name},       " optional: what / matches on
      \ 'delete': function('s:delete'),     " optional: (item) removes it, as dd
      \ 'keys': [{'key': '<CR>', 'hint': 'open', 'call': function('s:open')},
      \          {'key': ':Thing'}],        " without 'call', only a hint
      \ }, {'myplugin_dir': dir})           " set as buffer variables before fetch
```

| Function | What it does |
| --- | --- |
| `roumail_lists#open(name, spec, vars)` | Open the list in buffer `name`, set `vars` as its buffer variables (what the spec's functions read), fetch, and go to the first item. |
| `roumail_lists#item()` | The item under the cursor, `{}` when not on one. |
| `roumail_lists#row()` | The row under the cursor, `{}` on the heading. A row without `item` is a heading among the rows (a group's, say) and can carry what its keys need. |
| `roumail_lists#refresh()` | Fetch again, as `r`. |
| `roumail_lists#delete()` | Remove the item under the cursor and fetch again, as `dd`. |
| `roumail_lists#set(items)` | List `items` instead, without fetching. |
| `roumail_lists#draw()` | Draw the items again, after a change to how they show. |
| `roumail_lists#close()` | Close the list, as `q`. |

Rows come in the order `rows` returns them; filtered, `rows` gets the matching
items best first, and may order them as it likes. The spec's functions run in
the list's buffer.

## Install

```vim
Plug 'roumail/vim-lists'
```

## Development

```sh
vim -Nu NONE -i NONE -Es -S test/run.vim   # TEST=<pattern> runs some
```
