NAME
====

Path::Map - map paths to handlers

SYNOPSIS
========

    my $mapper = Path::Map.new(
        '/x/y/z' => 'XYZ',
        '/a/b/c' => 'ABC',
        '/a/b'   => 'AB',

        '/date/:year/:month/:day' => 'Date',

        # Every path beginning with 'seo' is mapped the same.
        '/seo/*' => 'slurpy',
    );

    if my $match = $mapper.lookup('/date/2013/12/25') {
        # $match->handler is 'Date'
        # $match->variables is { year => 2012, month => 12, day => 25 }
    }

    # Add more mappings later
    $mapper->add_handler($path => $target)

DESCRIPTION
===========

    This class maps paths to handlers. The paths can contain variable path
    segments, which match against any incoming path segment, where the matching
    segments are saved as named variables for later retrieval.  Simple
    validation may be added to any named segment in the form of a
    L<doc:Callable>.

    Note that the handlers being mapped to can be any arbitrary data, not just
    strings as illustrated in the synopsis.

    This is a port of the Perl 5 module of the same name by Matt Lawrence, see
    L<Path::Map|https://metacpan.org/pod/Path::Map>

Implementation
--------------

    Path::Map uses hash trees to do lookups, with the goal of producing a fast
    and lightweight routing implementation.  No performance testing has been
    done on the Perl 6 version at this stage, however this should in theory mean
    that performance does not degrade significantly when a large number of
    branches are added to a router at the same depth, and that the order in which
    routes are added will not need to consider the frequency of lookup for a
    particular path.

METHODS
=======

### method new

```
method new(
    *@maps
) returns Mu
```

The constructor. Takes a list of pairs and adds each via L<#add_handler>

### method add_handler

```
method add_handler(
    Str $path, 
    $handler, 
    *%constraints
) returns Mu
```

Adds a single item to the mapping.

The path template should be a string comprising slash-delimited path segments, where a path segment may contain any character other than the slash. Any segment beginning with a colon (`:`) denotes a mandatory named variable. Empty segments, including those implied by leading or trailing slashes are ignored.

For example, these are all identical path templates:

    /a/:var/b
    a/:var/b/
    //a//:var//b//

The order in which these templates are added has no bearing on the lookup, except that later additions with identical templates overwrite earlier ones.

Templates containing a segment consisting entirely of `'*'` match instantly at that point, with all remaining segments assigned to the `values` of the match as normal, but without any variable names. Any remaining segments in the template are ignored, so it only makes sense for the wildcard to be the last segment.

    my $map = Path::Map.new('foo/:foo/*', 'Something');
    my match = $map.lookup('foo/bar/baz/qux');
    $match.variables; # (foo => 'bar')
    $match.values; # (bar baz qux)

### method lookup

```
method lookup(
    Str $path
) returns Mu
```

Returns a L<Path::Map::Match> object if the path matches a known template.

The two main methods on the match object are:

  * handler

    The handler that was matched, identical to whatever was originally passed to
    L<#add_handler>.

  * variables

    The named path variables as a L<doc:Hash>.

### method handlers

```
method handlers() returns Mu
```

Returns all of the handlers in no particular order.

SEE ALSO
========

[Path::Router](Path::Router), [Path::Map](https://metacpan.org/pod/Path::Map) for Perl 5

AUTHOR
======

[Francis Whittle](mailto:fj.whittle@gmail.com)

KUDOS
=====

[Matt Lawrence](mailto:mattlaw@cpan.org) - author of Perl 5  [Path::Map](https://metacpan.org/pod/Path::Map) module.

COPYRIGHT
=========

This library is free software; you can redistribute it and/or modify it under the terms of the  [Artistic License 2.0](http://www.perlfoundation.org/artistic_license_2_0)
