/* rr ADDR...: print the 32-bit word at each (aligned) physical address via /dev/mem
 * rr -w ADDR VALUE: write VALUE, then print the register */
typedef unsigned long u64;
static long sc(long n, long a, long b, long c, long d, long e, long f)
{
	register long x8 asm("x8") = n, x0 asm("x0") = a, x1 asm("x1") = b,
		x2 asm("x2") = c, x3 asm("x3") = d, x4 asm("x4") = e, x5 asm("x5") = f;
	asm volatile("svc 0" : "+r"(x0) : "r"(x8), "r"(x1), "r"(x2), "r"(x3), "r"(x4), "r"(x5) : "memory");
	return x0;
}
static u64 hex(const char *s)
{
	u64 v = 0;
	if (s[0] == '0' && (s[1] == 'x' || s[1] == 'X')) s += 2;
	for (; *s; s++)
		v = v * 16 + (*s <= '9' ? *s - '0' : (*s | 32) - 'a' + 10);
	return v;
}
static void put(char *b, int *p, u64 v, int n)
{
	for (int i = n - 1; i >= 0; i--) b[(*p)++] = "0123456789abcdef"[(v >> (4 * i)) & 15];
}
static int rr(long argc, char **argv)
{
	long fd = sc(56, -100, (long)"/dev/mem", 0x101002 /* O_RDWR|O_SYNC */, 0, 0, 0);
	if (fd < 0) return 1;
	int wr = argc == 4 && argv[1][0] == '-' && argv[1][1] == 'w';
	for (long i = wr ? 2 : 1; i < (wr ? 3 : argc); i++) {
		u64 a = hex(argv[i]) & ~3UL, pg = a & ~0xfffUL;
		long m = sc(222, 0, 0x1000, 3 /* PROT_READ|WRITE */, 1 /* MAP_SHARED */, fd, pg);
		if (m < 0 && m > -4096) return 2;
		if (wr)
			*(volatile unsigned *)(m + (a - pg)) = (unsigned)hex(argv[3]);
		unsigned v = *(volatile unsigned *)(m + (a - pg));
		sc(215, m, 0x1000, 0, 0, 0, 0);
		char b[32]; int p = 0;
		b[p++] = 'R'; b[p++] = ' '; b[p++] = '0'; b[p++] = 'x'; put(b, &p, a, 8);
		b[p++] = ' '; b[p++] = '0'; b[p++] = 'x'; put(b, &p, v, 8); b[p++] = '\n';
		sc(64, 1, (long)b, p, 0, 0, 0);
	}
	return 0;
}
asm(".global _start\n_start:\n ldr x0, [sp]\n add x1, sp, #8\n bl rr_main\n mov x8, #93\n svc 0\n");
long rr_main(long argc, char **argv) { return rr(argc, argv); }
