; What Zed puts a run button beside: each #test procedure (its name is the
; task's test_name, ZED_CUSTOM_test_name), and a program's main.

((constant_declaration
   name: (identifier) @run @test_name
   value: (procedure
     (directive
       name: (directive_name) @_directive)))
  (#eq? @_directive "#test")
  (#set! tag rain-test))

((source_file
   (constant_declaration
     name: (identifier) @run @_main
     value: (procedure)))
  (#eq? @_main "main")
  (#set! tag rain-main))
