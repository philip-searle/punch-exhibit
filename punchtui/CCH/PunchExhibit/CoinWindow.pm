package CCH::PunchExhibit::CoinWindow;

use Modern::Perl;
use Exporter;
use Curses::UI::Window;
use Curses::UI::Common;
use Curses;

our $VERSION = 0.05;
our @ISA = qw(Curses::UI::Window Curses::UI::Common);
our @EXPORT_OK = qw(new);

my $user_prompt = <<PROMPT;


	Insert a one pound coin to punch your own paper tape!

	Our paper tape machine will punch it out as machine-readable
	ITA2/US-TTY Baudot-Murray code, as well as human-readable
	sideways text.

	Your donation goes towards keeping this exhibit -- and our
	museum -- running.  Thank you!`
PROMPT

sub new {
	my ($class, %userargs) = @_;

	keys_to_lowercase(\%userargs);

	my %args = (
		-width => 80,
		-height => 24,
		-x => 0,
		-y => 0,
		-border => 1,
		-title => 'XXX',
		%userargs
	);
	my $this = $class->SUPER::new( %args);
	$this->create_children;
	$this->layout;
	return $this;
}

sub create_children {
	my $this = shift;

	my $textbg = $this->add(
		'textbg', 'Label',
		-x => 0, -y => 0,
		-width => 78, -height => 10,
		-dim => 0, -paddingspaces => 1,
		-text => $user_prompt,
		-fg => 'yellow', -bold => 1
	);
}

1;

