
//~ double linked list

Linked_List :: struct($T: Type) {
    first, last: *T;
}

linked_list_add :: (list: *$L/Linked_List, value: *L.T) {
    if !list.first {
        list.first = value;
        list.last = value;
    } else {
        list.last.next = value;
        value.prev = list.last;
        list.last = value;
    }
}

linked_list_pop :: (list: *$L/Linked_List) -> *L.T {
    if !list.last return null;

    value := list.last;
    linked_list_remove(list, value);

    return value;
}

linked_list_remove :: (list: *$L/Linked_List, value: *L.T) {
    if value.prev value.prev.next = value.next;
    if value.next value.next.prev = value.prev;

    if value == list.first list.first = value.next;
    if value == list.last list.last = value.prev;

    value.next = null;
    value.prev = null;
}

for_expansion :: (list: $L/Linked_List, body: Code, flags: For_Flags) #expand {
    value: *L.T;
    index: int;

    if flags & .REVERSE {
        value = list.last;
        index = list.last - list.first;
    } else {
        value = list.first;
        index = 0;
    }

    while value {
#if flags & .POINTER {
            `it := value;
        } else {
            `it := value.*;
        }

        `it_index := index;

#if flags & .REVERSE {
            value = value.prev;
            index -= 1;
        } else {
            value = value.next;
            index += 1;
        }

#insert body;
    }
}

//~ bucket array

Bucket_Array :: struct($T: Type) {
    arena: *Arena;
    occupied: Linked_List(T);
    freed: Linked_List(T);
}

bucket_array_add :: (array: *Bucket_Array($T), value: T, stub: *T = null) -> *T {
    if !array.arena array.arena = make_arena();

    slot := linked_list_pop(*array.freed);
    if !slot {
        if !stub {
            default_stub :: T.{};
            stub = *default_stub;
        }

        slot = push_struct(array.arena, T, stub);
        if slot == stub return stub;
    }

    memcpy(slot, *value, size_of(T));
    linked_list_add(*array.occupied, slot);

    return slot;
}

bucket_array_remove :: (array: *Bucket_Array($T), value: *T) {
    linked_list_remove(*array.occupied, value);
    linked_list_add(*array.freed, value);
}

for_expansion :: (array: Bucket_Array($T), body: Code, flags: For_Flags) #expand {
    R :: cast(bool) (flags & .REVERSE);
    P :: cast(bool) (flags & .POINTER);
    for *=P <=R`it, `it_index: array.occupied {
#insert body;
    }
}

//~ temp array/view

tarray :: ($T: Type, reserve := 0) -> [..] T {
    return push_array(context.temp_arena, T, reserve);
}

tview :: ($T: Type, count: int) -> [] T {
    return push_view(context.temp_arena, T, count);
}