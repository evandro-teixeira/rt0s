MEMORY
{
	FLASH(rx): ORIGIN = 0x8000000, LENGTH = 0xffff
	RAM(rw): ORIGIN = 0x20000000, LENGTH = 0x1fff
}

SECTIONS
{
	.text :
	{

	} > FLASH
	.data :
	{

	} > RAM
	. = ORIGIN(RAM)+LENGTH(RAM);
	. = ALIGN(4);
	PROVIDE(RAMEND = .);
	/DISCARD/ :
	{
		*(.comment)
		*(.ARM.attributes)
	}
}

