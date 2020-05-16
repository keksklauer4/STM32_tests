SECTIONS
{
        . = 0x0;

        .text :  {  *(.text)   }

        .data :
        {
          *(.data)
          *(.rom)
        }

        /* internal RAM starts at 0x20000000 */
        . = 0x20000000;
        .ram : { *(.ram) }

        .bss :
        {
          *(.bss)
          *(.ram)
        }
}
