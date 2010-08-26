imgdir = $(DRACUT_MODDIR)/30olpc-activation/act-gui-images

img_DATA = _0.565 _1.565 _2.565 _3.565 _4.565 _5.565 _6.565 _7.565 _8.565 \
	_9.565 _A.565 _B.565 _C.565 _D.565 _E.565 _F.565 _H.565 _N.565 _S.565 \
	startup.565 question.565 \
	stolen_msg.565 stolen.565 stolen_XO.565 \
	locked_msg.565 locked_XO.565 lock.565 \
	NAND_flash_outline.565 NAND_flash.565 \
	SD_card_outline.565 SD_card.565 \
	USB_key_outline.565 USB_key.565 \
	wireless11.565 wireless1.565 wireless6.565 wireless_outline.565 wireless.565

IMAGES = $(patsubst %.565,%.png,$(img_DATA))

%.565: %.png
	pngtopnm $< | $(srcdir)/ppmto565.py -z -o $@

CLEANFILES = $(img_DATA)
EXTRA_DIST = $(IMAGES) ppmto565.py

