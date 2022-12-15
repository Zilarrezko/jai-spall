# jai-spall

Just my own functionality for spall binary format from https://github.com/colrdavidson/spall
Kinda for my own use but you can use it. It will probably become obsolete as spall is most likely going to change frequently.
This is only for the binary format.

This is generally how I use it:

```go
main :: () {
	sprofiler = init_spall_profiler(1024*1024*1024*2); // 2GB, Around about max that the spall wasm version can handle
	// ...
	
	// Before I exit
	spall_finalize();
}

foo :: () {
	spall_scope("foo"); // profiling the entire procedure from the top of the procedure
	// ...
	{
		spall_scope("other scope"); // profiling a sub-scope
		// ...
	}
	spall_begin("load"); // profiling the same way as a sub-scope without making a scope
	// ...
	spall_end(); // ending the spall_begin
}
```
Pretty simple
sprofiler is a global at the moment. We could add it to the context. Though I'm not really sure how standard of a thing that is.
