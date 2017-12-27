VERSIONS := $(shell jq -r '.version + "-" + .arch' versions/*.json)
LIBVIRT_TARGETS := $(foreach v,$(VERSIONS),alpine-$(v)-libvirt.box)
VIRTUALBOX_TARGETS := $(foreach v,$(VERSIONS),alpine-$(v)-virtualbox.box)
ALL_TARGETS := $(foreach v,$(VERSIONS),alpine-$(v)-libvirt.box alpine-$(v)-virtualbox.box)

help:
	@echo "Call make with one (or more) of these targets:\\n";

	@echo "libvirt:"
	@echo "\tbuild-libvirt - this will build all versions"
	@$(foreach t,$(LIBVIRT_TARGETS),echo \\t$(t);)

	@echo;

	@echo "virtualbox:"
	@echo "\tbuild-virtualbox - this will build all versions"
	@$(foreach t,$(VIRTUALBOX_TARGETS),echo \\t$(t);)

build-libvirt: $(LIBVIRT_TARGETS)

build-virtualbox: $(VIRTUALBOX_TARGETS)

$(LIBVIRT_TARGETS): alpine-%-libvirt.box: answers-libvirt.tmp provision.sh alpine.json versions/%.json Vagrantfile.template
	$(RM) $@
	PACKER_KEY_INTERVAL=10ms packer build -only=$(@:.box=) -on-error=abort -var-file=versions/$*.json alpine.json
	@echo BOX successfully built!
	@echo to add to local vagrant install do:
	@echo vagrant box add -f $(@:-libvirt.box=) $@

answers-libvirt.tmp: answers
	sed 's,/dev/sda,/dev/vda,g' $< >$@

$(VIRTUALBOX_TARGETS): alpine-%-virtualbox.box: answers-libvirt.tmp provision.sh alpine.json versions/%.json Vagrantfile.template
	$(RM) $@
	PACKER_KEY_INTERVAL=10ms packer build -only=$(@:.box=) -on-error=abort -var-file=versions/$*.json alpine.json
	@echo BOX successfully built!
	@echo to add to local vagrant install do:
	@echo vagrant box add -f $(@:-virtualbox.box=) $@

.PHONY: buid-libvirt build-virtualbox
