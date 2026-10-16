library TestFwd6
    public function Callee takes nothing returns nothing
    endfunction
    public function Caller takes nothing returns nothing
        call TestFwd6_Callee()
    endfunction
endlibrary
