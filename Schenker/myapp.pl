# myapp.pl
#!/usr/bin/env perl
package MyApp;
use Schenker;

get '/' => sub {
    'Hello, world!';
};

get '/hello/:name' => sub {
    my $args = shift;
    "Hello, $args->{name}!";
};
