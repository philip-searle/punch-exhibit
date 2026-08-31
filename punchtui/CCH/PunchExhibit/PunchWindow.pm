package CCH::PunchExhibit::PunchWindow;

use Modern::Perl;
use Exporter;
use Curses::UI::Window;
use Curses::UI::Common;
use Curses;
use CCH::PunchExhibit::Fonts;

our $VERSION = 0.05;
our @ISA = qw(Curses::UI::Window Curses::UI::Common);
our @EXPORT_OK = qw(new);

my $UC_SPROCKET = "\N{U+00B7}";
my $UC_SPACE = "\N{U+0020}";
my $UC_HOLE = "\N{U+25CF}";

my $user_prompt = <<PROMPT;


	Enter your name below and press ENTER.

	Our paper tape machine will punch it out as machine-readable
	ITA2/US-TTY Baudot-Murray code, as well as human-readable
	sideways text.

	You get up to 40 characters, so make good use of them!
PROMPT

use Data::Dumper;
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
		-fg => 'green', -bold => 1
	);
	
	my $preview_win = $this->add(
		'preview_window', 'Window',
		-title => "Punch Tape Preview",
		-border => 1, -bg => 'white', -fg => 'black',
		-x => 0, -y => 14,
		-width => 80, -height => 8
	);
	
	my $tape_preview = $preview_win->add(
		'tape_preview', 'Label',
		-x => 0, -y => 0,
		-width => 78, -height => 6,
		-text => preview_tape(""),
		-textalignment => 'right'
	);
	
	my $handle_name = sub {
		my $widget = shift;
		my $name = $widget->text();
		$tape_preview->text(preview_tape($name));
		$preview_win->draw();
	};
	
	my $namefield = $this->add(
		'namefield', 'TextEntry',
		-x => 19, -y => 11,
		-width => 42, -height => 1,
		-toupper => 1,
		-onchange => $handle_name,
		-sbborder => 0, -showlines => 1,
		-maxlength => 40
	);
	$namefield->set_binding(sub { }, CUI_TAB(), KEY_BTAB());
	$namefield->focus;
	$this->set_binding(sub { $this->{-onenter}->($namefield) }, KEY_ENTER);
}

sub preview_tape {
	my $text = shift;
	my ($preview, $flip, $p) = ('', undef, undef);
	for my $b (0 .. 4) {
		my $cur_code = \%CCH::PunchExhibit::Fonts::ita2_ustty_letters;
		my $alt_code = \%CCH::PunchExhibit::Fonts::ita2_ustty_figures;
		for my $c (split //, $text) {
			($flip, $p, $cur_code, $alt_code) = lookup_code_char($c, $cur_code, $alt_code);
			if (defined $flip) {
				$preview .= $flip & (1<<$b) ? $UC_HOLE : $UC_SPACE;
			}
			$preview .= $p & (1<<$b) ? $UC_HOLE : $UC_SPACE;
		}
		$preview .= "\n";
		if ($b == 1) {
			$preview .= $UC_SPROCKET x 78 . "\n";
		}
	}
	return $preview;
}

1;

