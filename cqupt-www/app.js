/**
 * CQUPT Schedule App - Official Website JS (Single-Screen Landing Page Edition)
 * Optimized for minimalist landing layout: scroll dynamics, and copy-actions.
 */

document.addEventListener('DOMContentLoaded', () => {

    /* ==========================================================================
       1. SCROLL-DYNAMIC HEADER
       ========================================================================== */
    const header = document.getElementById('header');
    
    const handleScroll = () => {
        if (window.scrollY > 20) {
            header.classList.add('scrolled');
        } else {
            header.classList.remove('scrolled');
        }
    };
    
    window.addEventListener('scroll', handleScroll);
    handleScroll(); // Initial check on load


    /* ==========================================================================
       2. ONE-CLICK COPY QQ GROUP NUMBER
       ========================================================================== */
    const copyQQBtnHero = document.getElementById('btn-copy-qq');
    const toastHero = document.getElementById('copy-toast');

    const copyToClipboard = (text, toastEl) => {
        if (navigator.clipboard && navigator.clipboard.writeText) {
            navigator.clipboard.writeText(text).then(() => {
                showToast(toastEl);
            }).catch(err => {
                console.error('Failed to copy text: ', err);
                fallbackCopyTextToClipboard(text, toastEl);
            });
        } else {
            fallbackCopyTextToClipboard(text, toastEl);
        }
    };

    const fallbackCopyTextToClipboard = (text, toastEl) => {
        const textArea = document.createElement("textarea");
        textArea.value = text;
        
        // Avoid scrolling to bottom
        textArea.style.top = "0";
        textArea.style.left = "0";
        textArea.style.position = "fixed";

        document.body.appendChild(textArea);
        textArea.focus();
        textArea.select();

        try {
            const successful = document.execCommand('copy');
            if (successful) {
                showToast(toastEl);
            }
        } catch (err) {
            console.error('Fallback: Oops, unable to copy', err);
        }

        document.body.removeChild(textArea);
    };

    const showToast = (toastEl) => {
        if (!toastEl) return;
        toastEl.classList.add('show');
        setTimeout(() => {
            toastEl.classList.remove('show');
        }, 2000);
    };

    if (copyQQBtnHero) {
        copyQQBtnHero.addEventListener('click', () => {
            copyToClipboard('1051832310', toastHero);
        });
    }


    /* ==========================================================================
       3. SCROLL-REVEAL ANIMATIONS (INTERSECTION OBSERVER)
       ========================================================================== */
    const revealElements = [
        document.querySelector('.hero-content'),
        document.querySelector('.hero-preview')
    ];

    // Configure CSS style for initial invisible state and reveal transitions
    const revealStyle = document.createElement('style');
    revealStyle.innerHTML = `
        .reveal-init {
            opacity: 0;
            transform: translateY(30px);
            transition: opacity 0.8s cubic-bezier(0.4, 0, 0.2, 1), 
                        transform 0.8s cubic-bezier(0.4, 0, 0.2, 1);
        }
        .reveal-visible {
            opacity: 1;
            transform: translateY(0);
        }
    `;
    document.head.appendChild(revealStyle);

    // Set observer to reveal items
    if ('IntersectionObserver' in window) {
        const observer = new IntersectionObserver((entries, observer) => {
            entries.forEach(entry => {
                if (entry.isIntersecting) {
                    entry.target.classList.add('reveal-visible');
                    observer.unobserve(entry.target);
                }
            });
        }, {
            threshold: 0.1,
            rootMargin: '0px 0px -30px 0px'
        });

        revealElements.forEach(el => {
            if (el) {
                el.classList.add('reveal-init');
                observer.observe(el);
            }
        });
    }
});
