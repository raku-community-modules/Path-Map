[![Actions Status](https://github.com/raku-community-modules/Path-Map/actions/workflows/linux.yml/badge.svg)](https://github.com/raku-community-modules/Path-Map/actions) [![Actions Status](https://github.com/raku-community-modules/Path-Map/actions/workflows/macos.yml/badge.svg)](https://github.com/raku-community-modules/Path-Map/actions) [![Actions Status](https://github.com/raku-community-modules/Path-Map/actions/workflows/windows.yml/badge.svg)](https://github.com/raku-community-modules/Path-Map/actions)

NAME
====

Path::Map - map paths to handlers

SYNOPSIS
========

```raku
my $mapper = Path::Map.new(
  '/x/y/z' => 'XYZ',
  '/a/b/c' => 'ABC',
  '/a/b'   => 'AB',

  '/date/:year/:month/:day' => 'Date',

  # Every path beginning with 'seo' is mapped the same.
  '/seo/*' => 'slurpy',
);

if $mapper.lookup('/date/2013/12/25') -> $match {
    # $match.handler is 'Date'
    # $match.variables is ( year => 2012, month => 12, day => 25 )
}

# Add more mappings later
$mapper.add_handler(Str $path, Mu $target, :key(Callable $constraint), ...)
```

DESCRIPTION
===========

This class maps (or "routes") paths to handlers. The paths can contain variable path segments, which match against any incoming path segment, where the matching segments are saved as named variables for later retrieval. Simple validation may be added to any named segment in the form of a `Callable`.

Note that the handlers being mapped to can be any arbitrary data, not just strings as illustrated in the synopsis.

This is a functional port of the Perl 5 module of the same name by Matt Lawrence, see [Path::Map](https://metacpan.org/pod/Path::Map).

Implementation
--------------

Path::Map uses hash trees to do look-ups, with the goal of producing a fast and lightweight routing implementation. No performance testing has been done on the Perl 6 version at this stage, however this should in theory mean that performance does not degrade significantly when a large number of branches are added to a router at the same depth, and that the order in which routes are added will not need to consider the frequency of lookup for a particular path.

METHODS
=======

### method new

```raku
method new(
    *@maps
) returns Mu
```

The constructor. Takes a list of pairs and adds each via L<#add_handler>. Pairs may be of the form C«$path => $handler» or C«$path => ($handler, *%constraints)»

### method add_handler

```raku
method add_handler(
    Str $path,
    $handler,
    *%constraints
) returns Mu
```

Adds a single item to the mapping.

The path template should be a string comprising slash-delimited path segments, where a path segment may contain any character other than the slash. Any segment beginning with a colon (`:`) denotes a mandatory named variable. Empty segments, including those implied by leading or trailing slashes are ignored.

For example, these are all identical path templates:

```raku
/a/:var/b
a/:var/b/
//a//:var//b//
```

The order in which templates are added will affect the lookup only when a named segment has differing keys, Thus:

```raku
$map.add_handler('foo/:foo/bar', 'A');
$map.add_handler('foo/:foo/baz', 'B');
```

produces the same tree as:

```raku
$map.add_handler('foo/:foo/baz', 'B');
$map.add_handler('foo/:foo/bar', 'A');
```

however:

```raku
$map.add_handler('foo/:bar/baz', 'A');
$map.add_handler('foo/:ban/baz', 'B');
```

will always resolve `'foo/*/baz'` to `'A'`, and:

```raku
$map.add_handler('foo/:ban/baz', 'B');
$map.add_handler('foo/:bar/baz', 'A');
```

will always resolve `'foo/*/baz'`; to `'B'`.

Templates containing a segment consisting entirely of `'*'` match instantly at that point, with all remaining segments assigned to the `values` of the match as normal, but without any variable names. Any remaining segments in the template are ignored, so it only makes sense for the wildcard to be the last segment.

```raku
my $map = Path::Map.new('foo/:foo/*', 'Something');
my match = $map.lookup('foo/bar/baz/qux');
$match.variables; # (foo => 'bar')
$match.values; # (bar baz qux)
```

Additional named arguments passed to `add_handler` validate the named variables in the path specification with the corresponding key using a `Callable`; this will be called with the value of the segment as the only argument, and should return a `True` or `False` response. No exception handling is performed by the `lookup` method, so any Exceptions or Failures are liable to prevent further look-ups on alternative paths. Multiple constraints for the same segment may be used with different constraints, provided each handler uses a different key.

```raku
$map.add_handler('foo/:bar', 'Something even', :bar({ try { +$_ %% 2 } }));
$map.add_handler('foo/:baz', 'Something odd', :baz({ try { 1 + $_ %% 2 } }));
$match = $map.lookup('foo/42'); # succeeds first validation; .handler eq 'Something even';
$match = $map.lookup('foo/21'); # succeeds second validation; .handler eq 'Something odd';
$match = $map.lookup('foo/seven'); # fails all validation; returns Nil;
```

Validation blocks can specify their (single) argument as rw to allow the mapped value to be transformed during validation:

```raku
    $map.add_handler('foo/:bar', 'Transform!', :bar(-> $bar is rw { try { $bar = Int($bar) } }));
    $map.lookup('foo/42').variables<bar>; # Int
    $map.lookup('foo/qux'); # Does not validate; Nil
```

### multi method lookup

```raku
multi method lookup(
    Str $path
) returns Mu
```

Returns a C<Path::Map::Match> object if the path matches a known template.

Calling a `Path::Map` object directly is equivalent to calling its lookup method.

The two main methods on the `Path::Map::Match` object are:

  * handler

The handler that was matched, identical to whatever was originally passed to [add_handler](#add_handler).

  * variables

The named path variables as a `Hash`.

The `mapper` that matched the path and associated `values` are also accessible as methods of the `Path::Map::Match` object.

For convenience, You can call a `Path::Map::Match` object directly if its `handler` implements the `Callable` role - in which case the matched `variables` will be passed to the handler.

### method handlers

```raku
method handlers() returns Mu
```

Returns all of the handlers in no particular order.

TRAITS
======

When `use`ing Path::Map with :traits you may specify a `Code` block as `is Path::Map(:type<path/to/map>)` and it will be stored as a mapping in the `Path::Map` namespace. This will try to use the type constraints from any parameter definitions:

```raku
use Path::Map :traits;

sub handle_things(Int :$baz) is Path::Map(:foo<bar/:baz>) { ... };

...

use Path::Map;

Path::Map<foo>.lookup('bar/100').handler; # handle_things
Path::Map<foo>.lookup('bar/qux').handler; # Nil
```

SEE ALSO
========

[Path::Router](Path::Router), [Path::Map](https://metacpan.org/pod/Path::Map) for Perl

AUTHOR
======

Francis Whittle

KUDOS
=====

Matt Lawrence

COPYRIGHT
=========

Copyright 2016 - 2017 Francis Whittle

Copyright 2024 Raku Community

This library is free software; you can redistribute it and/or modify it under the terms of the [Artistic License 2.0](http://www.perlfoundation.org/artistic_license_2_0)

