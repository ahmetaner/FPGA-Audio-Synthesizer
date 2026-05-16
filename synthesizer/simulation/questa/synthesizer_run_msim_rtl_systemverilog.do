transcript on
if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}
vlib rtl_work
vmap work rtl_work

vlog  -work work +incdir+C:/ELE432/synthesizer {C:/ELE432/synthesizer/audio_pll.vo}
vlog  -work work +incdir+C:/ELE432/synthesizer {C:/ELE432/synthesizer/sine_rom.v}
vlib audio_pll
vmap audio_pll audio_pll
vlog  -work audio_pll +incdir+C:/ELE432/synthesizer/audio_pll {C:/ELE432/synthesizer/audio_pll/audio_pll_0002.v}
vlog -sv -work work +incdir+C:/ELE432/synthesizer {C:/ELE432/synthesizer/synthesizer_top.sv}
vlog -sv -work work +incdir+C:/ELE432/synthesizer {C:/ELE432/synthesizer/synthesizer_sound_interface.sv}
vlog -sv -work work +incdir+C:/ELE432/synthesizer {C:/ELE432/synthesizer/i2s_transmitter.sv}
vlog -sv -work work +incdir+C:/ELE432/synthesizer {C:/ELE432/synthesizer/i2c_config.sv}
vlog -sv -work work +incdir+C:/ELE432/synthesizer {C:/ELE432/synthesizer/ps2_receiver.sv}
vlog -sv -work work +incdir+C:/ELE432/synthesizer {C:/ELE432/synthesizer/scan_code_to_bus.sv}
vlog -sv -work work +incdir+C:/ELE432/synthesizer {C:/ELE432/synthesizer/voice_allocator.sv}
vlog -sv -work work +incdir+C:/ELE432/synthesizer {C:/ELE432/synthesizer/voice_module.sv}
vlog -sv -work work +incdir+C:/ELE432/synthesizer {C:/ELE432/synthesizer/oscillator.sv}
vlog -sv -work work +incdir+C:/ELE432/synthesizer {C:/ELE432/synthesizer/adsr_envelope.sv}
vlog -sv -work work +incdir+C:/ELE432/synthesizer {C:/ELE432/synthesizer/digital_mixer.sv}
vlog -sv -work work +incdir+C:/ELE432/synthesizer {C:/ELE432/synthesizer/iir_lowpass_filter.sv}
vlog -sv -work work +incdir+C:/ELE432/synthesizer {C:/ELE432/synthesizer/counter_module.sv}

vlog -sv -work work +incdir+C:/ELE432/synthesizer {C:/ELE432/synthesizer/tb_synthesizer_top.sv}

vsim -t 1ps -L altera_ver -L lpm_ver -L sgate_ver -L altera_mf_ver -L altera_lnsim_ver -L cyclonev_ver -L cyclonev_hssi_ver -L cyclonev_pcie_hip_ver -L rtl_work -L work -L audio_pll -voptargs="+acc"  tb_synthesizer_top

add wave *
view structure
view signals
run -all
