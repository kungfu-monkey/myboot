@**************************************
@author:kungfu_monkey
@filename:start.S
@**************************************
.text
.global _start
.global irq
_start:
	b reset
	ldr pc,_undefined_instruction								@�����ж�������
	ldr pc,_software_interrupt
	ldr pc,_prefetch_abort
	ldr pc,_data_abort
	ldr pc,_not_used
	ldr pc,_irq
	ldr pc,_fiq

_undefined_instruction: .word undefined_instruction
_software_interrupt: .word software_interrupt
_prefetch_abort: .word prefetch_abort
_data_abort: .word data_abort
_not_used: .word not_used
_irq: .word irq
_fiq: .word fiq

undefined_instruction:
	nop
software_interrupt:
	nop
prefetch_abort:
	nop
data_abort:
	nop
not_used:
	nop
irq:
	sub lr,lr,#4
	stmfd sp!,{r0-r12,lr}
	bl irq_handler
	ldmfd sp!,{r0-r12,pc}^
fiq:
	nop
reset:
	bl set_svc
	bl disable_watchdog
	bl disable_interrupt
	bl disable_mmu
	bl clock_init  
	bl mem_init
	bl stack_init
	bl nand_init
@	bl iram_to_ram
	bl copy_to_ram	
	bl bss_clean
@	ldr pc,=mmu_demo
  ldr pc,=main
@	bl led_debug
	
@halt:											@��mcuһֱִ��������  ��ֹmcu�ܷ�
@	b halt

set_svc:
	mrs r0,cpsr
	bic r0,r0,#0xff				
	orr r0,r0,#0xd3						@��ֹirq,fiq,����Ϊsvcģʽ
	msr cpsr_c,r0
	mov pc,lr

#define  pwtcon 0xe2700000	
disable_watchdog:					  @�رտ��Ź�
	ldr r0,=pwtcon
	mov r1,#0x0
	str r1,[r0]
	mov pc,lr
	
disable_interrupt:					@�����ж�
	mvn r0,#0x0             
	ldr r1,=0xf2000014
	str r0,[r1]
	
	ldr r1,=0xf2100014
	str r0,[r1]
	
	ldr r1,=0xf2200014
	str r0,[r1]
	
	ldr r1,=0xf2300014
	str r0,[r1]
	mov pc,lr

disable_mmu:
	mcr p15,0,r0,c7,c5,0
	mcr p15,0,r0,c7,c6,1
	mrc p15,0,r0,c1,c0,0					@�ر�MMU���ر�dcache(Icacheû�йر�)
	bic r0, r0, #0x00000007
	mcr p15,0,r0,c1,c0,0
	mov pc, lr
	
#define	APLL_LOCK 0xe0100000
#define	MPLL_LOCK 0xe0100008
#define CLK_DIV0 0xe0100300
#define MPLL_CON 0xe0100108
#define APLL_CON 0xe0100100
#define CLK_SRC  0xe0100200

#define DIV_VAL ((0x0<<0)|(4<<4)|(4<<8)|(1<<12)|(3<<16)|(1<<20)|(4<<24)|(1<<28))
#define APLL_VAL ((1<<31)|(3<<8)|(125<<16)|(1<<0))
#define MPLL_VAL ((1<<31)|(12<<8)|(667<<16)|(1<<0))


clock_init:
	ldr r0,=APLL_LOCK										@�����ȶ���ʱ������
	ldr r1,=0xfff
	str r1,[r0]
	
	ldr r0,=MPLL_LOCK
	ldr r1,=0xfff
	str r1,[r0]

	ldr r0, =CLK_DIV0										@���÷�Ƶ����
	ldr r1, =DIV_VAL
	str r1, [r0]
	
	ldr r0, =APLL_CON                   @APLL����Ϊ1000MHz
	ldr r1, =APLL_VAL
	str r1, [r0]
	
	ldr r0, =MPLL_CON										@MPLL����Ϊ667MHz
	ldr r1, =MPLL_VAL
	str r1, [r0]
	
	ldr r0, =CLK_SRC										@ʱ��Դѡ��  ʹ�þ�����PLL
	ldr r1, =0x10001111											
	str r1, [r0]
	
	mov pc, lr
	
	
iram_to_ram:								@��iram���Ƶ��ڴ�dram������
	adr r0, _start						@_start��ǰ����λ�ã�Ϊ0xd0020010 
	ldr r1,=_start						@_start�����ӵ�ַ��Ϊ0x20008000
	ldr r3,=bss_start           @bin�ļ�����λ��,bin�ļ��в���Ҫ����bss��
	cmp r0,r1
	moveq pc,lr
	
copy_loop:
	ldr r2,[r0],#4						@��iram���ݸ���r2,Ȼ���Լ�4     r2=[r0],r0=r0+4
	str r2,[r1],#4						@[r1]=r2,r1=r1+4
	cmp r1,r3
	bne copy_loop
		
	mov pc,lr

stack_init:
	msr cpsr_c, #0xd2
	ldr sp, =0x3e000000				@�˴�ʵ�����õ���r13_irq,�ڴ淶ΧΪ0x2000_0000~0x3fff_ffff			
	msr cpsr_c, #0xd3
	ldr sp, =0x3f000000				@�˴�ʵ�����õ���r13_svc
	mov pc, lr

copy_to_ram:
	mov r0,#0									@r0,r1,r2��Ϊ����nand_to_ram��3������
	ldr r1,=_start
	ldr r2,=bss_start
	sub r2,r2,r1
	sub r1,r1,#0x10           @ǰ16byteΪ��ͷ����_start-16~_start�ϣ��Ա�֤����λ�ö��룬��_start��ʼ

	
	mov ip,lr
	bl nand_to_ram
	mov lr,ip
	
	mov pc,lr


bss_clean:
	ldr r0,=bss_start					@���ջ
	ldr r1,=bss_end
	cmp r0,r1
	moveq pc,lr
	

clean_loop:
	mov r2,#0
	str r2,[r0],#4
	cmp r0,r1
	bne clean_loop
	
	mov pc,lr


led_debug:          
	ldr	r0,=0xe0200280      @ GPJ2CON���ƼĴ���
	ldr	r1,=0x00001010
	str	r1,[r0]             @ ����GPJ2_0��GPJ2_1,GPJ2_2,GPJ2_3Ϊ�����, λ[3:0]=0b0001��ӦGPJ2_0
	
	ldr	r0,=0xe0200284      @ GPJ2DAT���ݼĴ���
	mov	r1,#0x0             @ �͵�ƽ����                       
	str	r1,[r0]  
	          
	mov pc,lr
	

