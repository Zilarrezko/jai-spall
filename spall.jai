Spall_Profiler :: struct {
    mem: *u8;
    cur: s64;
    cap: s64;
    start_time: Apollo_Time;
    on: bool;
    file: File;
    mutex: Mutex;
}


make_spall_profiler :: (path: string, size: int, allocator := context.allocator) -> Spall_Profiler {
    sp: Spall_Profiler;
    sp.mem = alloc(size, allocator);
    sp.cur = 0;
    sp.cap = size;
    sp.start_time = current_time_monotonic();
    sp.on = true;
    header: Spall_Header = .{SPALL_MAGIC, 1, 1.0, 0};
    memcpy(sp.mem, *header, size_of(Spall_Header));
    sp.cur += size_of(Spall_Header);
    init(*sp.mutex);
    ok: bool;
    sp.file, ok = file_open(path, for_writing=true, keep_existing_content=false);
    if !ok {
        print("ERROR: Couldn't open profile.spall file for writing.\n");
        sp.on = false;
    }
    return sp;
}


spall_begin :: (sp: *Spall_Profiler, $$scope_name: string = "") {
    if !sp.on {
        return;
    }
    event: Spall_Begin_Event = ---;
    event.type = .begin;
    event.category = 0;
    event.pid = 0;
    event.tid = context.thread_index;
    event.time = cast(float64)to_microseconds(current_time_monotonic());
    event.name_len = cast(u8)scope_name.count;
    event.args_len = 0;
    lock(*sp.mutex);
    mem: *u8 = sp.mem + sp.cur;
    memcpy(mem, *event, size_of(Spall_Begin_Event));
    mem += size_of(Spall_Begin_Event);
    memcpy(mem, scope_name.data, scope_name.count);
    mem += scope_name.count;
    sp.cur = mem - sp.mem;
    unlock(*sp.mutex);
}


spall_end :: (sp: *Spall_Profiler) {
    if !sp.on {
        return;
    }
    event: Spall_End_Event = ---;
    event.type = .end;
    event.pid = 0;
    event.tid = context.thread_index;
    event.time = cast(float64)to_microseconds(current_time_monotonic());
    lock(*sp.mutex);
    mem: *u8 = sp.mem + sp.cur;
    memcpy(mem, *event, size_of(Spall_End_Event));
    mem += size_of(Spall_End_Event);
    sp.cur = mem - sp.mem;
    unlock(*sp.mutex);
}


spall_scope :: (sp: *Spall_Profiler, $$scope_name: string) #expand #no_debug {
    spall_begin(sp, scope_name);
    `defer spall_end(sp);
}


spall_flush :: (sp: *Spall_Profiler) {
    if sp.on && sp.cur > 0 {
        ok := file_write(*sp.file, sp.mem, sp.cur);
        if !ok {
            print("ERROR: Couldn't flush spall profiling data.\n");
            // Turn off the profiler?
        }
        sp.cur = 0;
    }
}


spall_destroy :: (sp: *Spall_Profiler) {
    file_close(*sp.file);
}


#scope_file

#import "Basic";  // Apollo_Time
#import "Thread"; // Mutex
#import "File";

// Spall Binary
Spall_Event_Type :: enum u8 {
    invalid :: 0;
    custom_data :: 1;
    stream_over :: 2;
    begin :: 3;
    end :: 4;
    instant :: 5;
    overwrite_timestamp :: 6;
}


SPALL_MAGIC :u64: 0x0BADF00D;
Spall_Header :: struct {
    magic: u64 #align 1; // Expected 0x0BADF00D
    version: u64 #align 1; // currently version 1
    timestamp_unit: float64 #align 1; // 1 is 1 microsecond
    must_be_0: u64 #align 1;
}


Spall_Begin_Event :: struct {
    type: Spall_Event_Type #align 1;
    category: u8 #align 1;
    pid: u32 #align 1;
    tid: u32 #align 1;
    time: float64 #align 1;
    name_len: u8 #align 1; // If the name is 0-terminated, len must include the 0
    args_len: u8 #align 1;
    // name will immediately follow
}


Spall_End_Event :: struct {
    type: Spall_Event_Type #align 1;
    pid: u32 #align 1;
    tid: u32 #align 1;
    time: float64 #align 1;
}
