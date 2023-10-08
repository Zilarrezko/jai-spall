# jai-spall

Just my own functionality for spall binary format from https://github.com/colrdavidson/spall
Kinda for my own use but you can use it. It will probably become obsolete as spall is most likely going to change frequently.
This is only for the binary format.

This is generally how I use it:

```jai
#add_context profiler: *Spall_Profiler;

main :: () {
	profiler := init_spall_profiler("profile.spall", 10*1024*1024);
	assert(ok, "Couldn't initialize profiler");
	context.profiler = New(Spall_Profiler);
	context.profiler.* = profiler;
	spall_begin(context.profiler, "main");
	// ...
	
	// Before I exit
	spall_finish(context.profiler);
}

// Just so I don't have to write context.profiler everytime
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
foo :: () {
	Timed_Scope("foo"); // profiling the entire procedure from the top of the procedure
	// ...
	{
		Timed_Scope("other scope"); // profiling a sub-scope
		// ...
	}
	Timed_Begin("load"); // profiling the same way as a sub-scope without making a scope
	// ...
	Timed_End(); // ending the spall_begin
}
```
