
Spall_Profiler :: struct {
    mem: *u8;
    cur: s64;
    cap: s64;
    start_time: Apollo_Time;
    file: File;
}

init_spall_profiler :: (path: string, size: int, allocator := context.allocator) -> Spall_Profiler, bool {
    sp: Spall_Profiler;
    sp.mem = alloc(size, allocator);
    sp.cur = 0;
    sp.cap = size;
    sp.start_time = current_time_monotonic();
    header: Spall_Header = .{MANUAL_SPALL_MAGIC, 1, 1.0, 0};
    memcpy(sp.mem, *header, size_of(Spall_Header));
    sp.cur += size_of(Spall_Header);
    init(*spall_mutex);
    ok: bool;
    sp.file, ok = file_open(path, for_writing=true, keep_existing_content=false);
    return sp, ok;
}

spall_begin :: (profiler: *Spall_Profiler, $$scope_name: string = "") {
    event: Spall_Begin_Event = ---;
    event.type = .begin;
    event.category = 0;
    event.pid = 0;
    event.tid = context.thread_index;
    event.time = cast(float64)to_microseconds(current_time_monotonic() - profiler.start_time);
    event.name_len = cast(u8)scope_name.count;
    event.args_len = 0;
    lock(*spall_mutex);
    if profiler.cur + size_of(Spall_Begin_Event) + scope_name.count > profiler.cap
        spall_flush(profiler);
    mem: *u8 = profiler.mem + profiler.cur;
    memcpy(mem, *event, size_of(Spall_Begin_Event));
    mem += size_of(Spall_Begin_Event);
    memcpy(mem, scope_name.data, scope_name.count);
    mem += scope_name.count;
    profiler.cur = mem - profiler.mem;
    unlock(*spall_mutex);
}

spall_end :: (profiler: *Spall_Profiler) {
    event: Spall_End_Event = ---;
    event.type = .end;
    event.pid = 0;
    event.tid = context.thread_index;
    event.time = cast(float64)to_microseconds(current_time_monotonic() - profiler.start_time);
    lock(*spall_mutex);
    if profiler.cur + size_of(Spall_End_Event) > profiler.cap
        spall_flush(profiler);
    mem: *u8 = profiler.mem + profiler.cur;
    memcpy(mem, *event, size_of(Spall_End_Event));
    mem += size_of(Spall_End_Event);
    profiler.cur = mem - profiler.mem;
    unlock(*spall_mutex);
}

spall_scope :: (profiler: *Spall_Profiler, $$scope_name: string) #expand #no_debug {
    spall_begin(profiler, scope_name);
    `defer spall_end(profiler);
}

spall_flush :: (profiler: *Spall_Profiler) -> bool {
    ok := true;
    if profiler.cur > 0 {
        ok = file_write(*profiler.file, profiler.mem, profiler.cur);
        profiler.cur = 0;
    }
    return ok;
}

spall_finish :: (profiler: *Spall_Profiler) {
    spall_flush(profiler);
    file_close(*profiler.file);
}

#scope_file

#import "File";
#import "Basic";
#import "Thread";

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

MANUAL_SPALL_MAGIC :u64: 0x0BADF00D;
NATIVE_SPALL_MAGIC :u64: 0xABADF00D;
Spall_Header :: struct {
    magic: u64 #align 1; // Expected 0x0BADF00D or 0xABADF00D
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
    // name string will immediately follow
}

Spall_End_Event :: struct {
    type: Spall_Event_Type #align 1;
    pid: u32 #align 1;
    tid: u32 #align 1;
    time: float64 #align 1;
}

spall_mutex: Mutex;
