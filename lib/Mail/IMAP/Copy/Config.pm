package Mail::IMAP::Copy::Config;

use strict;
use warnings;

my %VALID_OPTIONS = (
    'username' => qr/^\S*$/,
    'password' => qr/^.*$/,
    'host'     => qr/^.*$/,
    'port'     => qr/^\d*$/,
    'ssl'      => qr/^(?:on|off)$/,
    'tls'      => qr/^(?:on|off)$/,
    'peek'     => qr/^(?:on|off)$/,
    'maildir'  => qr/^.*$/
);

sub load {
    my ( $class, $file ) = @_;
    my %config;

    open( my $fh, '<', $file ) or die("Unable to open $file for reading: $!");

    while ( my $line = readline($fh) ) {
        chomp $line;

        next if $line =~ /^\s*(#|$)/;

        die('Syntax error') unless $line =~ /^\s*(\S*)\s*"(.*)"\s*(#|$)/;

        my ( $key, $value ) = ( $1, $2 );

        die("Unrecognized option '$key'") unless defined $VALID_OPTIONS{$key};
        die("Invalid value for '$key'") unless $value =~ $VALID_OPTIONS{$key};

        $config{$key} = $value;
    }

    close $fh;

    return bless \%config, $class;
}

1;
