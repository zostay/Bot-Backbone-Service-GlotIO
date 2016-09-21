package Bot::Backbone::Service::GlotIO;

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
