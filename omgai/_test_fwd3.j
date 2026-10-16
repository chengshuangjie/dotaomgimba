library TestFwd3
    public function Caller takes nothing returns nothing
        call Callee()
    endfunction
    public function Callee takes nothing returns nothing
    endfunction
endlibrary
