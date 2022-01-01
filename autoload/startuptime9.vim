vim9script

# (documented in autoload/startuptime.vim)
def startuptime9#Extract(
      file: string,
      options: dict<any>,
      other_event_type: number,
      sourcing_event_type: number
    ): list<any>
  var result = []
  var lines = readfile(file)
  var occurrences: dict<any>
  for line in lines
    if strchars(line) ==# 0 || line[0] !~# '^\d$'
      continue
    endif
    if line =~# ': --- N\=VIM STARTING ---$'
      add(result, [])
      occurrences = {}
    endif
    var idx = stridx(line, ':')
    var times = split(line[: idx - 1], '\s\+')
    var event = line[idx + 2 :]
    var type = other_event_type
    if len(times) ==# 3
      type = sourcing_event_type
    endif
    var key = type .. '-' .. event
    if has_key(occurrences, key)
      occurrences[key] += 1
    else
      occurrences[key] = 1
    endif
    # 'finish' time is reported as 'clock' in --startuptime output.
    var item = {
      'event': event,
      'occurrence': occurrences[key],
      'finish': str2float(times[0]),
      'type': type
    }
    if type ==# sourcing_event_type
      item['self+sourced'] = str2float(times[1])
      item.self = str2float(times[2])
      item.start = item.finish - item['self+sourced']
    else
      item.elapsed = str2float(times[1])
      item.start = item.finish - item.elapsed
    endif
    var types = []
    if options.sourcing_events
      add(types, sourcing_event_type)
    endif
    if options.other_events
      add(types, other_event_type)
    endif
    if index(types, item.type) !=# -1
      add(result[-1], item)
    endif
  endfor
  return result
enddef

def s:Mean(numbers: list<any>): float
  if len(numbers) ==# 0
    throw 'vim-startuptime: cannot take mean of empty list'
  endif
  var result = 0.0
  for number in numbers
    result += number
  endfor
  result = result / len(numbers)
  return result
enddef

# (documented in autoload/startuptime.vim)
def s:StandardDeviation(
    numbers: list<any>, ddof: number, mean: float = str2float('nan')): float
  var mean2 = isnan(mean) ? s:Mean(numbers) : mean
  var result = 0.0
  for number in numbers
    var diff = mean2 - number
    result += diff * diff
  endfor
  result = result / (len(numbers) - ddof)
  result = sqrt(result)
  return result
enddef

# (documented in autoload/startuptime.vim)
def startuptime9#Consolidate(
    items: list<any>, tfields: list<string>): list<any>
  var lookup = {}
  for try in items
    for item in try
      var key = item.type .. '-' .. item.occurrence .. '-' .. item.event
      if has_key(lookup, key)
        for tfield in tfields
          if has_key(item, tfield)
            add(lookup[key][tfield], item[tfield])
          endif
        endfor
        lookup[key].tries += 1
      else
        lookup[key] = deepcopy(item)
        for tfield in tfields
          if has_key(lookup[key], tfield)
            # Put item in a list.
            lookup[key][tfield] = [lookup[key][tfield]]
          endif
        endfor
        lookup[key].tries = 1
      endif
    endfor
  endfor
  var result = values(lookup)
  for item in result
    for tfield in tfields
      if has_key(item, tfield)
        var mean = s:Mean(item[tfield])
        # Use 1 for ddof, for sample standard deviation.
        var std = s:StandardDeviation(item[tfield], 1, mean)
        item[tfield] = {'mean': mean, 'std': std}
      endif
    endfor
  endfor
  # Sort on mean start time, event name, then occurrence.
  var Compare = (i1, i2) =>
        i1.start.mean !=# i2.start.mean
        ? (i1.start.mean <# i2.start.mean ? -1 : 1)
        : (i1.event !=# i2.event
           ? (i1.event <# i2.event ? -1 : 1)
           : (i1.occurrence !=# i2.occurrence
              ? (i1.occurrence <# i2.occurrence ? -1 : 1)
              : 0))
  sort(result, Compare)
  return result
enddef