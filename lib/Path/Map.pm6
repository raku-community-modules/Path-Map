use v6;

class Path::Map { ... }

class Path::Map::Match {
  has Path::Map $.mapper is required;
  has @.values;
  has %.variables;

  method handler() {
    $!mapper.target;
  }
}

my $componentrx = /
  [ <?after '/'> | ^^ ] [ $<slurpy> = '*' | [ $<var> = ':' ]? $<path> = <-[/*]>+ ]
  /;

class Path::Map does Associative {
  has %.map handles <DELETE-KEY keys values pairs kv>;

  has @!resolv;

  has $.target is rw;
  has $.key is rw;
  has Bool $.slurpy is rw = False;

  method new(Path::Map:U: *@maps) {
    my $obj := Path::Map.bless;
    for @maps {
      when Pair {
	$obj.add_handler(.key, .value);
      }
    }

    $obj;
  }

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

  multi method lookup(Path::Map:D $mapper:
		      @components is copy,
		      %variables  is copy = {},
		      @values     is copy = [],
		      $value?) {
    if $!key {
      %variables{$!key} = $value;
      @values.push($value);
    }

    if @components {
      my $c = @components[0];
      if $mapper{$c}:exists {
	my @maps = $mapper{$c};

	my $i = 0;
	for @maps -> $map {
	  if my $match = $map.lookup(@components[1..*], %variables, @values, $c) {
	    return $match
	  };
	}
      } else {
	return Nil unless $!slurpy;
      }
    }

    return Nil unless $!target;

    @values.push(|@components) if @components;

    Path::Map::Match.new(:$mapper, :%variables, :@values);
  }

  multi method lookup(Str $path) {
    self.lookup($path.comb(/<-[/]>+/).Array);
  }

  method handlers {
    (self.target, %!map.values.map: { .handlers }).grep({ defined $_ }).flat.unique;
  }

  method !dynamic($key) {
    @!resolv.grep({ $^p.value.($key) })».key;
  }

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
