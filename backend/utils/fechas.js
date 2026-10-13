const claveFecha = (d) => `${d.getFullYear()}-${d.getMonth() + 1}-${d.getDate()}`;

const soloFecha = (d) => new Date(d.getFullYear(), d.getMonth(), d.getDate());

const limpiarHora = (h) =>
  String(h).replace(/[–—]/g, '-').replace(/\s+/g, ' ').trim().toUpperCase();

module.exports = { claveFecha, soloFecha, limpiarHora };