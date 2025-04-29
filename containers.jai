
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