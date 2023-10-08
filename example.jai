
// We'll want to add this to the context, unless we want to pass it around everywhere.
// So for other threads you'll have to create the profiler before making the threads and
// then passing the profiler in as thread data. In such a case, having only a pointer to pass
// is a good idea
#add_context profiler: *Spall_Profiler;

main :: () {
    profiler, ok := init_spall_profiler("profile.spall", 10*1024*1024);
    assert(ok, "Couldn't initialize profiler");
    context.profiler = New(Spall_Profiler);
    context.profiler.* = profiler;
    spall_begin(context.profiler, "main");

    example1();
    example2();
    example3();

    spall_flush(context.profiler);
    spall_finish(context.profiler);
}

example1 :: () {
    spall_scope(context.profiler, "factorial");
    n :: 20;
    for i : 0..100_000 {
        f := 1;
        for j : 1..n {
            f = f*j;
        }
    }
}

example2 :: () {
    profiler := context.profiler;
    spall_scope(profiler, "fibonacci");
    a := 0;
    b := 1;
    n := 500;
    for i : 0..100 {
        for j : 1..n {
            a := 0;
            b := 1;
            spall_begin(profiler, "run");
            for k : 0..j {
                c := a + b;
                a = b;
                b = c;
            }
            spall_end(profiler);
        }
    }
}

// Maybe you want wrappers

Timed_Scope :: ($name: string) #expand #no_debug {
    spall_begin(context.profiler, name);
    `defer spall_end(context.profiler);
}
Timed_Begin :: ($name: string) #expand #no_debug {
    spall_begin(context.profiler, name);
}
Timed_End :: () #expand #no_debug {
    spall_end(context.profiler);
}
example3 :: () {
    Timed_Scope("prime_testing");
    for i : 2..100_000 {
        Timed_Scope("naive_prime_test");
        f: bool = true;
        for j : 2..i - 1 {
            if i % j == 0 {
                f = false;
                break;
            }
        }
    }
}

#load "spall.jai";
