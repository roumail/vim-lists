" Headless tests, from the repository's root:
"   vim -Nu NONE -i NONE -Es -S test/run.vim
" Prints one line per test and exits non-zero when one fails; TEST=<pattern>
" in the environment runs the tests whose names match.
set nocompatible hidden
let s:root = expand('<sfile>:p:h:h')
execute 'set runtimepath^=' . fnameescape(s:root)
execute 'source' fnameescape(s:root . '/plugin/roumail_lists.vim')

function! s:reset() abort
  silent! only
  silent! %bwipeout!
  let g:words = ['apple', 'banana', 'cherry']
  let g:picked = ''
endfunction

" A list of words, under a 'fruit' heading row when grouped
function! s:open(...) abort
  let l:grouped = a:0 && a:1
  call roumail_lists#open('test://words', {
        \ 'fetch': {-> g:words is v:null ? v:null : copy(g:words)},
        \ 'heading': {items -> ['Words (' . len(items) . ')']},
        \ 'rows': {items -> (l:grouped ? [{'lines': ['fruit'], 'group': 'fruit'}] : [])
        \   + map(copy(items), {_, w -> {'lines': [w], 'item': {'w': w}}})},
        \ 'id': {item -> item.w}, 'match': {item -> item.w},
        \ 'keys': [{'key': 'x', 'hint': 'pick',
        \   'call': {-> execute('let g:picked = roumail_lists#item().w')}},
        \          {'key': ':Cmd'}]}, {'mine': 1})
endfunction

function! s:test_open() abort
  call s:open()
  call assert_equal('test://words', bufname())
  call assert_equal(1, b:mine, 'vars are buffer variables')
  call assert_equal(['Words (3)  x pick  :Cmd  / filter  r refresh  q close',
        \ 'apple', 'banana', 'cherry'], getline(1, '$'))
  call assert_equal(2, line('.'), 'on the first item')
  call assert_equal('nofile', &buftype)
  call assert_equal(4, winheight(0))
  call assert_equal(2, winnr('$'), 'a window of its own')
endfunction

function! s:test_items_and_keys() abort
  call s:open()
  call cursor(1, 1)
  call assert_equal({}, roumail_lists#item(), 'the heading has no item')
  call assert_equal({}, roumail_lists#row())
  call cursor(3, 1)
  normal x
  call assert_equal('banana', g:picked)
  call assert_equal('', maparg(':Cmd', 'n'), 'a hint only maps nothing')
endfunction

function! s:test_group_rows() abort
  call s:open(1)
  call assert_equal(3, line('.'), 'on the first item, past the group row')
  call cursor(2, 1)
  call assert_equal({}, roumail_lists#item())
  call assert_equal('fruit', roumail_lists#row().group)
endfunction

function! s:test_refresh_keeps_item() abort
  call s:open()
  call cursor(3, 1)
  let g:words = ['zebra', 'apple', 'banana']
  normal r
  call assert_equal('banana', getline('.'))
  " Gone: the same line
  let g:words = ['zebra', 'apple']
  normal r
  call assert_equal(3, line('.'))
  " A fetch failing leaves the list as it was
  let g:words = v:null
  normal r
  call assert_equal(['zebra', 'apple'], getline(2, '$'))
endfunction

function! s:test_set_and_draw() abort
  call s:open()
  call roumail_lists#set(['kiwi'])
  call assert_equal(['Words (1)  x pick  :Cmd  / filter  r refresh  q close', 'kiwi'],
        \ getline(1, '$'))
  call assert_equal(2, winheight(0))
endfunction

function! s:test_filter() abort
  call s:open()
  call feedkeys("/an\<CR>", 'x')
  call assert_equal(['Words (3), 1 matching ''an''  x pick  :Cmd  / filter  r refresh  q close',
        \ 'banana'], getline(1, '$'))
  " r keeps it
  normal r
  call assert_equal(2, line('$'))
  " <Esc> goes back to the filter it had
  call feedkeys("/\<C-u>zz\<Esc>", 'x')
  call assert_equal(2, line('$'))
  call feedkeys("/\<BS>\<BS>\<CR>", 'x')
  call assert_equal(4, line('$'))
  call feedkeys("/xyz\<C-w>ch\<CR>", 'x')
  call assert_equal('cherry', getline(2))
endfunction

function! s:test_no_match_no_filter_key() abort
  call roumail_lists#open('test://plain', {'fetch': {-> [1]},
        \ 'heading': {_ -> ['Plain']}, 'rows': {items -> [{'lines': ['one'], 'item': {}}]},
        \ 'id': {_ -> 1}, 'keys': []}, {})
  call assert_equal('Plain  r refresh  q close', getline(1))
  call assert_equal('', maparg('/', 'n'))
endfunction

function! s:test_close() abort
  call s:open()
  normal q
  call assert_false(bufexists('test://words'))
  call assert_equal(1, winnr('$'))
  " The only window: it stays, empty
  call s:open()
  only
  normal q
  call assert_equal(1, winnr('$'))
  call assert_false(bufexists('test://words'))
endfunction

function! s:test_reopen_reuses_window() abort
  call s:open()
  wincmd p
  call s:open()
  call assert_equal(2, winnr('$'))
endfunction

let s:prefix = expand('<SID>') . 'test_'
let s:failed = 0
let s:names = []
let s:out = []
for s:line in split(execute('function'), "\n")
  if stridx(s:line, 'function ' . s:prefix) == 0
    call add(s:names, matchstr(s:line, '^function \zs[^(]\+'))
  endif
endfor
for s:name in s:names
  let s:label = matchstr(s:name, 'test_\zs\w\+')
  if !empty($TEST) && s:label !~# $TEST
    continue
  endif
  call s:reset()
  let v:errors = []
  try
    call call(s:name, [])
  catch
    call add(v:errors, v:exception . ' @ ' . v:throwpoint)
  endtry
  if empty(v:errors)
    call add(s:out, 'ok   ' . s:label)
  else
    let s:failed += 1
    call add(s:out, 'FAIL ' . s:label)
    call extend(s:out, map(copy(v:errors), '"     " . v:val'))
  endif
endfor
call add(s:out, s:failed ? s:failed . ' failed' : 'all passed')
call writefile(s:out, '/dev/stdout')
execute 'cquit' (s:failed ? 1 : 0)
