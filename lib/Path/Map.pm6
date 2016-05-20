use v6;

=NAME Path::Map - map paths to handlers

=begin SYNOPSIS

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

=end SYNOPSIS

=begin DESCRIPTION

    This class maps paths to handlers. The paths can contain variable path
    segments, which match against any incoming path segment, where the matching
    segments are saved as named variables for later retrieval.  Simple
    validation may be added to any named segment in the form of a
    L<doc:Callable>.

    Note that the handlers being mapped to can be any arbitrary data, not just
    strings as illustrated in the synopsis.

    This is a functional port of the Perl 5 module of the same name by Matt
    Lawrence, see L<Path::Map|https://metacpan.org/pod/Path::Map>.

=head2 Implementation

    Path::Map uses hash trees to do lookups, with the goal of producing a fast
    and lightweight routing implementation.  No performance testing has been
    done on the Perl 6 version at this stage, however this should in theory mean
    that performance does not degrade significantly when a large number of
    branches are added to a router at the same depth, and that the order in which
    routes are added will not need to consider the frequency of lookup for a
    particular path.

=end DESCRIPTION

class Path::Map { ... }

# Match class for lookup results.
class Path::Map::Match {
  has Path::Map $.mapper is required;
  has @.values;
  has %.variables;

  method handler() {
    $!mapper.target;
  }
}

# Regular expression for combing the path components out of a Str.
my $componentrx = /
  [ <?after '/'> | ^^ ] [ $<slurpy> = '*' | [ $<var> = ':' ]? $<path> = <-[/*]>+ ]
  /;

class Path::Map does Associative {
  # Hash providing storage of defined segments
  has %.map handles <DELETE-KEY keys values pairs kv>;

  # Array mapping resolvers & validators to path segments
  has @!resolv;

  has $.target is rw; #= Target / handler for this mapper.
  has $.key is rw; #= Key for named segments
  has Bool $.slurpy is rw = False; # Wildcard "slurpy" marker.

=head1 METHODS

  #| The constructor.  Takes a list of pairs and adds each via L<#add_handler>
  method new(Path::Map:U: *@maps) {
    my $obj := Path::Map.bless;
    for @maps {
      when Pair {
        $obj.add_handler(.key, .value);
      }
    }

    $obj;
  }

  #| Adds a single item to the mapping.
  method add_handler(Path::Map:D: Str $path, $handler, *%constraints) {
    my @vars;
    my Bool $slurpy = False;

    my Path::Map $mapper = self;

    for $path.comb($componentrx, :match).list -> $/ {
      if $slurpy || ($<slurpy>:exists) {
        $slurpy = True;
        last;
      }
      my $p = $<path>.Str;
      if $<var>:exists {
        push @vars, $p;
        $p = ($/.Str => %constraints{$<path>} // { True });
      }
      $mapper{$p} = Path::Map.new unless $mapper{$p}:exists;
      $mapper{$p}.key = $<path>.Str if $<var>:exists;
      $mapper = $mapper{$p};
    }

    $mapper.target = $handler;
    $mapper.slurpy = $slurpy;
  }

=begin pod

The path template should be a string comprising slash-delimited path segments,
where a path segment may contain any character other than the slash. Any
segment beginning with a colon (C<:>) denotes a mandatory named variable.
Empty segments, including those implied by leading or trailing slashes are
ignored.

For example, these are all identical path templates:

    /a/:var/b
    a/:var/b/
    //a//:var//b//

The order in which these templates are added has no bearing on the lookup,
except that later additions with identical templates overwrite earlier ones.

Templates containing a segment consisting entirely of C<'*'> match instantly
at that point, with all remaining segments assigned to the C<values> of the
match as normal, but without any variable names. Any remaining segments in the
template are ignored, so it only makes sense for the wildcard to be the last
segment.

    my $map = Path::Map.new('foo/:foo/*', 'Something');
    my match = $map.lookup('foo/bar/baz/qux');
    $match.variables; # (foo => 'bar')
    $match.values; # (bar baz qux)

=end pod

  # Looks up a path by array of segments
  multi method lookup(Path::Map:D $mapper:
                      @components is copy,
                      %variables  is copy = {},
                      @values     is copy = [],
                      $value?) {
    # Add value to segment variables and values if component is a named key
    if $!key {
      %variables{$!key} = $value;
      @values.push($value);
    }

    # Descend into segment
    if @components {
      my $c = @components[0];
      # Resolve and loop through child segment mappers.
      if $mapper{$c}:exists {
        my @maps = $mapper{$c};

        for @maps -> $map {
          # Lookup by stripping out the zeroeth component & return the first successful match.
          if my $match = $map.lookup(@components[1..*], %variables, @values, $c) {
            return $match
          };
        }
      } else {
        # Only allow continuations for slurpy matches.
        return Nil unless $!slurpy;
      }
    }

    # No target means no match.
    return Nil unless $!target;

    # Slurp the remaining components into values
    @values.push(|@components) if @components;

    # Successful match!
    Path::Map::Match.new(:$mapper, :%variables, :@values);
  }

  #| Returns a L<Path::Map::Match> object if the path matches a known template.
  multi method lookup(Str $path) {
    self.lookup($path.comb(/<-[/]>+/).Array);
  }

=begin pod

The two main methods on the match object are:

=item handler

    The handler that was matched, identical to whatever was originally passed to
    L<#add_handler>.

=item variables

    The named path variables as a L<doc:Hash>.

=end pod

  #| Returns all of the handlers in no particular order.
  method handlers {
    (self.target, %!map.values.map: { .handlers }).grep({ defined $_ }).flat.unique;
  }

  # Resolves and Validates named keys.
  method !dynamic($key) {
    @!resolv.grep({ $^p.value.($key) })».key;
  }

  # Associate callbacks.  The variants with Pair $keys may be prunable.

  multi method EXISTS-KEY(Pair $key) {
    %!map{$key.key}:exists;
  }

  multi method EXISTS-KEY($key) {
    quietly { %!map{$key | self!dynamic($key).any }:exists }
  }

  multi method AT-KEY(Pair $key) {
    %!map{$key.key};
  }

  multi method AT-KEY($key) {
    %!map{$key} // %!map{self!dynamic($key).list} || Nil;
  }

  multi method ASSIGN-KEY(Pair $key, $new) {
    @!resolv.push: $key;
    %!map{$key.key} = $new;
  }

  multi method ASSIGN-KEY($key, $new) {
    %!map{$key} = $new;
  }

  multi method BIND-KEY(Pair $key, \new) {
    @!resolv.push: $key;
    %!map{$key.key} := new;
  }

  multi method BIND-KEY($key, \new) {
    %!map{$key} := new;
  }
}

=begin pod

=head1 SEE ALSO

L<Path::Router>, L<Path::Map|https://metacpan.org/pod/Path::Map> for Perl 5

=head1 AUTHOR

L<Francis Whittle|mailto:fj.whittle@gmail.com>

=head1 KUDOS

Matt Lawrence - author of Perl 5 L<Path::Map|https://metacpan.org/pod/Path::Map>
module.  Please do not contact Matt with issues with the Perl 6 module.

=head1 COPYRIGHT

This library is free software; you can redistribute it and/or modify it under
the terms of the
L<Artistic License 2.0|http://www.perlfoundation.org/artistic_license_2_0>

=end pod
