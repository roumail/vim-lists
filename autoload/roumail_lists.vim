" vim-lists: a list in a window of its own at the bottom, a heading with the
" list's keys, then its rows. What is listed and what its keys do come from
" the plugin listing it; how it opens, filters, redraws and closes is here,
" the same for every list.
"
" roumail_lists#open(name, spec, vars) opens the buffer name, sets vars as
" its buffer variables (what the spec's functions read), and fetches. spec:
"   fetch()     the items, or v:null on failure (the list is left as it was);
"               run on opening and on r
"   heading(items)  its lines, the first one the list's title; the title gets
"               ', N matching ...' while filtered, and the keys' hints
"   rows(items) [{'lines': [...], 'item': item}, ...]: each item's lines, in
"               order; a row without 'item' is a heading among them, and may
"               carry anything else (roumail_lists#row() returns it)
"   id(item)    what stays the same for an item across fetches: the cursor
"               stays on its item when the list is redrawn
"   match(item) optional: the text / filters on, fuzzily, as fzf does
"   keys        [{'key': '<CR>', 'hint': 'open', 'call': Funcref}, ...]: the
"               list's own keys, in the order the heading shows them; one
"               without 'call' is only a hint (a command, say)
"   delete(item) optional: removes the item, from wherever fetch finds it;
"               dd, in every list that can, and the list is fetched again
" Every list has dd (with delete), / (with match), r and q, after its own keys.


function! roumail_lists#open(name, spec, vars) abort
  " A window of its own, so q and :q close only the list, never a window of yours
  let l:winnr = bufwinnr('^' . a:name . '$')
  if l:winnr > 0
    execute l:winnr . 'wincmd w'
  else
    execute 'silent botright split' fnameescape(a:name)
  endif
  setlocal buftype=nofile bufhidden=wipe noswapfile nowrap nobuflisted winfixheight
  call extend(b:, a:vars)
  let b:roumail_lists = {'spec': a:spec, 'items': [], 'filter': '', 'rows': [],
        \ 'line_row': []}
  let l:i = 0
  for l:key in a:spec.keys
    if has_key(l:key, 'call')
      execute 'nnoremap <buffer><silent>' l:key.key
            \ '<Cmd>call roumail_lists#key(' . l:i . ')<CR>'
    endif
    let l:i += 1
  endfor
  if has_key(a:spec, 'delete')
    nnoremap <buffer><silent> dd <Cmd>call roumail_lists#delete()<CR>
  endif
  if has_key(a:spec, 'match')
    nnoremap <buffer><silent> / <Cmd>call roumail_lists#filter()<CR>
  endif
  nnoremap <buffer><silent> r <Cmd>call roumail_lists#refresh()<CR>
  nnoremap <buffer><silent> q <Cmd>call roumail_lists#close()<CR>
  call roumail_lists#refresh()
  call s:first()
endfunction

function! roumail_lists#key(i) abort
  call b:roumail_lists.spec.keys[a:i].call()
endfunction

" dd: the item under the cursor goes, and the list is fetched again
function! roumail_lists#delete() abort
  let l:item = roumail_lists#item()
  if !empty(l:item)
    call b:roumail_lists.spec.delete(l:item)
    call roumail_lists#refresh()
  endif
endfunction

" Fetches the items again; the filter stays
function! roumail_lists#refresh() abort
  let l:items = b:roumail_lists.spec.fetch()
  if l:items isnot v:null
    call roumail_lists#set(l:items)
  endif
endfunction

" Lists items instead, without fetching
function! roumail_lists#set(items) abort
  let b:roumail_lists.items = a:items
  call roumail_lists#draw()
endfunction

" Draws the items again, as after a change to how they show
function! roumail_lists#draw() abort
  let l:item = roumail_lists#item()
  let l:id = empty(l:item) ? v:null : b:roumail_lists.spec.id(l:item)
  let l:line = line('.')
  call s:draw()
  let l:at = l:id is v:null ? -1 : s:line_of(l:id)
  call cursor(l:at > 0 ? l:at : min([l:line, line('$')]), 1)
endfunction

function! s:draw() abort
  let l:list = b:roumail_lists
  let l:spec = l:list.spec
  let l:items = s:matching()
  let l:heading = l:spec.heading(l:list.items)
  let l:hints = map(copy(l:spec.keys), {_, k -> k.key . (has_key(k, 'hint') ? ' ' . k.hint : '')})
        \ + (has_key(l:spec, 'delete') ? ['dd remove'] : [])
        \ + (has_key(l:spec, 'match') ? ['/ filter'] : []) + ['r refresh', 'q close']
  let l:heading[0] .= (empty(l:list.filter) ? ''
        \   : ', ' . len(l:items) . ' matching ' . string(l:list.filter))
        \ . '  ' . join(l:hints, '  ')
  let l:list.rows = l:spec.rows(l:items)
  let l:list.line_row = repeat([-1], len(l:heading))
  let l:lines = copy(l:heading)
  let l:i = 0
  for l:row in l:list.rows
    call extend(l:lines, l:row.lines)
    call extend(l:list.line_row, repeat([l:i], len(l:row.lines)))
    let l:i += 1
  endfor
  setlocal modifiable
  silent %delete _
  call setline(1, l:lines)
  setlocal nomodifiable nomodified
  execute 'resize' min([line('$'), get(g:, 'roumail_lists_height', 15)])
endfunction

" The items matching the filter, best first, as fzf: space-separated words
" each match
function! s:matching() abort
  let l:list = b:roumail_lists
  return empty(l:list.filter) ? l:list.items
        \ : matchfuzzy(l:list.items, l:list.filter, {'text_cb': l:list.spec.match})
endfunction

" The first line of the item with this id, or -1
function! s:line_of(id) abort
  let l:list = b:roumail_lists
  let l:line = 1
  for l:i in l:list.line_row
    if l:i >= 0 && has_key(l:list.rows[l:i], 'item')
          \ && l:list.spec.id(l:list.rows[l:i].item) ==# a:id
      return l:line
    endif
    let l:line += 1
  endfor
  return -1
endfunction

" To the first item's line, else the line after the heading
function! s:first() abort
  let l:list = b:roumail_lists
  let l:line = 1
  for l:i in l:list.line_row
    if l:i >= 0 && has_key(l:list.rows[l:i], 'item')
      call cursor(l:line, 1)
      return
    endif
    let l:line += 1
  endfor
  call cursor(min([count(l:list.line_row, -1) + 1, line('$')]), 1)
endfunction

" The row under the cursor, {} on the heading
function! roumail_lists#row() abort
  if !exists('b:roumail_lists')
    return {}
  endif
  let l:i = get(b:roumail_lists.line_row, line('.') - 1, -1)
  return l:i < 0 ? {} : b:roumail_lists.rows[l:i]
endfunction

" The item under the cursor, {} when not on one
function! roumail_lists#item() abort
  return get(roumail_lists#row(), 'item', {})
endfunction

function! roumail_lists#filter() abort
  let l:list = b:roumail_lists
  let l:before = l:list.filter
  while 1
    call s:draw()
    call s:first()
    redraw
    echo '/' . l:list.filter
    try
      let l:key = getchar()
    catch /^Vim:Interrupt$/
      let l:key = "\<Esc>"
    endtry
    let l:key = type(l:key) == v:t_number ? nr2char(l:key) : l:key
    if l:key ==# "\<CR>"
      break
    elseif l:key ==# "\<Esc>"
      let l:list.filter = l:before
      call s:draw()
      call s:first()
      break
    elseif l:key ==# "\<BS>" || l:key ==# "\<C-h>"
      let l:list.filter = strcharpart(l:list.filter, 0, strchars(l:list.filter) - 1)
    elseif l:key ==# "\<C-w>"
      let l:list.filter = substitute(l:list.filter, '\S*\s*$', '', '')
    elseif l:key ==# "\<C-u>"
      let l:list.filter = ''
    elseif l:key =~# '^\p$'
      let l:list.filter .= l:key
    endif
  endwhile
  redraw
  echo ''
endfunction

function! roumail_lists#close() abort
  if winnr('$') > 1
    close
  else
    enew
  endif
endfunction
