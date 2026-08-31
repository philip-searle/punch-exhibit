package CCH::PunchExhibit::CoinMech;

use Modern::Perl;
use Exporter;
use Try::Tiny;

my $pi_module_import = eval {
	require RPi::WiringPi;
	require RPi::Pin;
	RPi::WiringPi->import();
	RPi::Pin->import();
	1;
};

our $VERSION = 0.05;
our @ISA = qw(Exporter);
our @EXPORT = qw(
	pi_init
	pi_info
);

my $COINMECH_PIN = 21;

# Taken from RPi::Const so we an run without it available
my $INPUT = 0;
my $PUD_UP= 2;
my $EDGE_FALLING = 1;

my $pi;
sub pi_init {
	try {
		my ($callback) = @_;
		$pi = RPi::WiringPi->new();

		my $pin = $pi->pin($COINMECH_PIN, '/COIN');
		$pin->mode($INPUT);
		$pin->pull($PUD_UP);
		$pin->set_interrupt($EDGE_FALLING, $callback, 250);

		$pi->auto_dispatch_interrupts(1);
		return undef;
	} catch {
		return $_;
	}
}

sub pi_info {
	try {
		return "PI not present or failed to initialize" unless defined $pi;
		my $system = $pi->pi_details;
		my $temp = $pi->core_temp;
		my $gpio = $pi->gpio_info;
		return <<INFO;
System: $system
  Temp: $temp
  GPIO: $gpio
INFO
	} catch {
		return $_;
	}
}

1;

