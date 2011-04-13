# Copyright (C) 2011 Tamil s.a.r.l. - http://www.tamil.fr
#
# This file is part of Chargeur SUDOC Koha.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

package Sudoc::Converter;
use Moose;


# Moulinette SUDOC
has sudoc => ( is => 'rw', isa => 'Sudoc', required => 1 );

# Les exemplaires courants. 
# ->{rcr}->{id}->{915}
#              ->{930}
#              ->{999}
# 076797597:
#   915:
#   917:
#   930:
#   999:
# 243615450:
#   915:
#   930:
#   991:
has item => ( is => 'rw', isa => 'HashRef' );


# On supprime un certain nombre de champs de la notice SUDOC entrante
sub clear {
    my ($self, $record) = @_;
}


# Création des exemplaires Koha en 995 en fonction des données locales SUDOC
sub itemize {
    my ($self, $record) = @_;

    my $myrcr = $self->sudoc->c->{$self->sudoc->iln}->{rcr};
    # On crée la structure de données items
    my $item = {};
    for my $field ( $record->field('9..') ) {
        my $value = $field->subfield('5');
        next unless $value;
        my ($rcr, $id) = $value =~ /(.*):(.*)/;
        unless ( $myrcr->{$rcr} ) {
            # Cas, improbable, d'un RCR qui ne serait pas dans la liste des RCR
            # FIXME On pourrait le logguer quelque part.
            next;
        }
        $item->{$rcr} ||= {};
        $item->{$rcr}->{$id} ||= {};
        $item->{$rcr}->{$id}->{$field->tag} = $field;
    }
    $self->item($item);

    # On crée les exemplaires à partir de 930 et 915
    while ( my ($rcr, $item_rcr) = each %$item ) {
        my $branch = $myrcr->{$rcr};
        while ( my ($id, $ex) = each %$item_rcr ) { # Les exemplaires d'un RCR
            # On prend le code à barre en 915$b, et s'il n'y en a pas on prend
            # EPN SUDOC ($id)
            my $barcode = $ex->{915};
            $barcode = $barcode->subfield('b')  if $barcode;
            $barcode = $id unless $barcode;
            my $cote = $ex->{930}->subfield('a');
            $record->append( MARC::Moose::Field::Std->new(
                tag => '995',
                subf => [
                    [ b => $branch ],
                    [ c => $branch ],
                    [ f => $barcode ],
                    [ k => $cote ],
                ]
            ) );
        }
    }
}


# On remplit le $9 Koha des champs liés à des autorités
sub authoritize {
    my ($self, $record) = @_;

    # Ne rien faire si c'est demandé pour l'ILN
    return unless $self->sudoc->c->{ $self->sudoc->iln }->{biblio}->{authoritize};

    my $zconn = $self->sudoc->koha->zauth();
    for my $field ( $record->field('5..|6..|7..') ) {
        my $ppn = $field->subfield('3');
        next unless $ppn;
        my $rs = $zconn->search_pqf( "\@attr 1=PPN $ppn" );
        if ($rs->size() >= 1 ) {
            my $auth = MARC::Moose::Record::new_from(
                $rs->record(0)->raw(), 'Iso2709' );
            my @sf;
            for ( @{$field->subf} ) {
                push @sf, [ $_->[0] => $_->[1] ];
                push @sf, [ '9' => $auth->field('001')->value ]
                    if $_->[0] eq '3';
            }
            $field->subf(\@sf);
        }
    }
}


# Fusion d'une notice entrante Sudoc avec une notice Koha
sub merge {
    my ($self, $record, $krecord) = @_;
}


1;
