import type { Locale } from "@/lib/types";

const ar = {
  nav: { home: "الرئيسية", explore: "استكشف", categories: "التصنيفات", offers: "العروض", about: "من نحن", contact: "تواصل معنا", menu: "القائمة", switchLang: "English" },
  search: { placeholder: "ابحث عن مكان أو خدمة…", button: "بحث", label: "بحث" },
  explore: { title: "استكشف الأماكن", results: "{n} نتيجة", empty: "لا توجد نتائج مطابقة. جرّب كلمات أخرى أو أزل بعض الفلاتر.", reset: "مسح الفلاتر" },
  filters: { category: "التصنيف", all: "الكل", sort: "الترتيب", apply: "تطبيق" },
  sort: { relevance: "الأكثر صلة", popular: "الأكثر شعبية" },
  view: { grid: "شبكة", list: "قائمة" },
  paging: { prev: "السابق", next: "التالي", page: "صفحة {p} من {n}" },
  place: { address: "العنوان", directions: "الاتجاهات في خرائط جوجل", phone: "الهاتف", whatsapp: "واتساب", website: "الموقع الإلكتروني", email: "البريد الإلكتروني",
    hours: "ساعات العمل", closed: "مغلق", services: "الخدمات", offers: "العروض المتاحة", related: "أماكن مشابهة", gallery: "معرض الصور", contact: "معلومات التواصل", social: "حسابات التواصل" },
  days: ["الأحد", "الاثنين", "الثلاثاء", "الأربعاء", "الخميس", "الجمعة", "السبت"],
  categories: { title: "التصنيفات", browse: "تصفح" },
  offers: { title: "العروض والخصومات", empty: "لا توجد عروض متاحة حاليًا. تابعنا قريبًا!", off: "خصم {v}%", fixed: "خصم {v} جنيه", validUntil: "ساري حتى {d}", conditions: "الشروط", at: "في" },
  contact: { title: "تواصل معنا", intro: "يسعدنا سماع رأيك أو اقتراحك.", name: "الاسم", email: "البريد الإلكتروني", subject: "الموضوع (اختياري)", message: "رسالتك", send: "إرسال",
    success: "تم استلام رسالتك، شكرًا لك!", error: "تعذّر إرسال الرسالة. حاول مرة أخرى لاحقًا.", rate: "أرسلت عددًا كبيرًا من الرسائل. حاول لاحقًا.", invalid: "تحقق من الحقول المطلوبة.", sending: "جارٍ الإرسال…" },
  home: { heroSearch: "ابحث في بورسعيد" },
  errors: { notFound: "الصفحة غير موجودة", notFoundBody: "الرابط غير صحيح أو تم نقل الصفحة.", back: "العودة للرئيسية" },
  footer: { rights: "جميع الحقوق محفوظة" },
};
type Messages = typeof ar;

const en: Messages = {
  nav: { home: "Home", explore: "Explore", categories: "Categories", offers: "Offers", about: "About", contact: "Contact", menu: "Menu", switchLang: "العربية" },
  search: { placeholder: "Search for a place or service…", button: "Search", label: "Search" },
  explore: { title: "Explore places", results: "{n} results", empty: "No matching results. Try different keywords or remove some filters.", reset: "Clear filters" },
  filters: { category: "Category", all: "All", sort: "Sort by", apply: "Apply" },
  sort: { relevance: "Most relevant", popular: "Most popular" },
  view: { grid: "Grid", list: "List" },
  paging: { prev: "Previous", next: "Next", page: "Page {p} of {n}" },
  place: { address: "Address", directions: "Directions on Google Maps", phone: "Phone", whatsapp: "WhatsApp", website: "Website", email: "Email",
    hours: "Opening hours", closed: "Closed", services: "Services", offers: "Available offers", related: "Similar places", gallery: "Photo gallery", contact: "Contact", social: "Social media" },
  days: ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"],
  categories: { title: "Categories", browse: "Browse" },
  offers: { title: "Offers & discounts", empty: "No offers available right now. Check back soon!", off: "{v}% off", fixed: "{v} EGP off", validUntil: "Valid until {d}", conditions: "Conditions", at: "at" },
  contact: { title: "Contact us", intro: "We'd love to hear your feedback or suggestions.", name: "Name", email: "Email", subject: "Subject (optional)", message: "Your message", send: "Send",
    success: "Your message was received. Thank you!", error: "We couldn't send your message. Please try again later.", rate: "You've sent many messages. Please try again later.", invalid: "Please check the required fields.", sending: "Sending…" },
  home: { heroSearch: "Search Port Said" },
  errors: { notFound: "Page not found", notFoundBody: "The link is wrong or the page has moved.", back: "Back to home" },
  footer: { rights: "All rights reserved" },
};

export const messages: Record<Locale, Messages> = { ar, en };
export const t = (locale: Locale): Messages => messages[locale];
export const fmt = (s: string, vars: Record<string, string | number>) => s.replace(/\{(\w+)\}/g, (_, k: string) => String(vars[k] ?? ""));
