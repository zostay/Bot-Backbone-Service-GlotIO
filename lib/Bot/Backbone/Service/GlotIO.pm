package Bot::Backbone::Service::GlotIO;
$Bot::Backbone::Service::GlotIO::VERSION = '0.001000';
use v5.10;
use Bot::Backbone::Service;

with qw(
    Bot::Backbone::Service::Role::Service
    Bot::Backbone::Service::Role::Responder
);

use WebService::GlotIO;

service_dispatcher as {
    command '!languages' => respond_by_method 'list_languages';
    # command '!versions' => given_parameters {
    #     parameter 'langauge' => ( amtch => qr/.+/ );
    # } respond_by_method 'list_versions';
};

has token => (
    is          => 'ro',
    isa         => 'Str',
    required    => 1,
);

has glotio => (
    is          => 'ro',
    isa         => 'WebService::GlotIO',
    required    => 1,
    lazy        => 1,
    builder     => '_build_glotio',
);

sub _build_glotio {
    my $self = shift;
    WebService::GlotIO->new(token => $self->token);
}

has languages => (
    is           => 'ro',
    isa          => 'ArrayRef',
    required     => 1,
    lazy         => 1,
    builder      => '_build_languages',
    traits       => [ 'Array' ],
    handles      => {
        all_languages => 'elements',
    },
);

sub _build_languages {
    my $self = shift;
    [ map { $_->{name} } @{ $self->glotio->runner->list_languages } ];
}

sub initialize {
    my $self = shift;

    $self->meta->building_dispatcher($self->dispatcher);
    for my $lang ($self->all_languages) {
        command "!$lang" => given_parameters {
            parameter 'program' => ( match_original => qr/.+/ );
        } respond {
            my $self = shift;
            $self->run_program($lang, @_);
        };
    }
    $self->meta->no_longer_building_dispatcher;
}

sub list_languages {
    my $self = shift;
    return join ', ', $self->all_languages;
}

sub run_program {
    my ($self, $lang, $message) = @_;
    my $res = $self->glotio->runner->run(
        language => $lang,
        program  => {
            files => [{
                name    => 'main.pl',
                content => $message->parameters->{program},
            }],
        },
    );

    my $output = '';
    $output .=  "(ERROR: $res->{error}) " if $res->{error};
    $output .=  join '', $res->{stdout}, $res->{stderr};
    $output  =~ s/\n/\N{SYMBOL FOR NEWLINE}/g;
    $output  =~ s/\r/\N{SYMBOL FOR CARRIAGE RETURN}/g;
    $output  =~ s/\s/ /g;
    $output  =  substr($output, 0, 197) . '...'
        if length $output > 200;

    return $output;
}

1;
__END__

=pod

=encoding UTF-8

=head1 NAME

Bot::Backbone::Service::GlotIO - Interface to glot.io smart pastebin

=head1 VERSION

version 0.001000

=head1 SYNOPSIS

    # in your bot config
    service glotio => (
        service => 'GlotIO',
    );

    # in chat
    alice> !languages
    bot> assembly, ats, bash, c, ...
    alice> !perl print "Hello, World!\n"
    bot> Hello, World!␤

=head1 DESCRIPTION

This service mediates the usage of L<WebService::GlotIO> to provide you
with the execution of a snipped via L<https://glot.io>.

=head1 DISPATCHER

=head2 !languages

   !languages

=head2 !$language $rest_of_message

   !perl print "Hello, world!\n"

This commands replies with the list of languages supported by the
C<glot.io> web service.

=head1 ATTRIBUTES

=head2 glotio

A L<WebService::GlotIO> instance. You can provide one upon construction,
otherwise it will be created automatically based on L</token>.

=head2 languages

Cache for the list of supported languages, stored as an array reference.
See L</all_languages> if you want to retrieve the expanded list.

Read-only. You shouldn't generally need to set this as the list is
populated automatically.

=head2 token

The token for connecting to C<glot.io> via L<WebService::GlotIO>.

Read-only, mandatory parameter to be set upon construction.

=head1 METHODS

=head1 all_languages

   my @langs = $obj->all_languages;

De-reference array-reference L</languages> to return the list of languages
currently supported by C<glot.io>.

=head2 initialize

Initialization method, called automatically at startup. Takes care to
load the list of L</languages> and adds a L</DISPATCHER> for each of
them, which in turns calls L</run_program> when invoked.

=head2 list_languages

   my $langs_string = $self->list_languages;

Returns a string with a list of all languages currently supported by
C<glot.io>, separated by a comma and a space.

=head2 run_program

Execute a program for the specific language. This is a callback function
called when the L</DISPATCHER> detects that a message for a specific
language has been sent.

Returns a string of at most 200 characters with any error followed by any
output generated while running the commands. If the aggregated error and
output are over 200 characters, the return value is properly truncated
and ellipsis characters C<...> appended (so in this case you only get 197
useful characters).

=head1 AUTHOR

Andrew Sterling Hanenkamp <hanenkamp@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2016 by Qubling Software LLC.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
