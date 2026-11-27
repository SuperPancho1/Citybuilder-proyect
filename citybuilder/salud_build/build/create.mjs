import fs from 'node:fs/promises';
import {Presentation,PresentationFile} from '@oai/artifact-tool';
const root='C:/Users/user/Documents/citybuilder/salud_build';
const p=Presentation.create({slideSize:{width:1280,height:720}});
const data=[
['Autocuidado y campañas de salud',[
['Ñañangareko ñandejehe','Cuidamos de nosotros mismos'],
['El guaraní en la salud','Consejos, advertencias y mensajes breves para el bienestar personal, familiar y comunitario.']]],
['Recomendaciones de autocuidado',[
['Autocuidado','Acciones cotidianas que una persona realiza para proteger su bienestar.'],
['Cuidado personal','Alimentación adecuada, higiene y atención a las necesidades del cuerpo.'],
['Cuidado familiar','Apoyo mutuo y acompañamiento en situaciones que afectan la salud.'],
['Prevención','Hábitos de cuidado y consulta profesional cuando corresponde.']]],
['Frases funcionales de autocuidado',[
['Ani rekaru heta','No comas demasiado. Recomienda evitar los excesos.'],
['Reñatende ne py’a rehe','Cuidá tu estómago. En este contexto, se refiere al cuidado digestivo.'],
['Eipytyvõ nde famíliape','Ayudá a tu familia. Promueve el apoyo y la responsabilidad compartida.']]],
['Vocabulario de prevención',[
['Jeikokuaa porã','Saber vivir bien: convivencia y hábitos que favorecen el bienestar.'],
['Tembi’u hekopete','Alimentación adecuada para las necesidades personales.'],
['Ñemopotĩ','Limpieza e higiene personal y del entorno.'],
['Pohã ñemohu’ã','Finalización del tratamiento con medicamentos según la indicación profesional.']]],
['Campañas de salud comunitaria',[
['Concepto','Comunicación dirigida a la comunidad para prevenir problemas de salud.'],
['Propósito','Informar, sensibilizar y orientar hacia una acción concreta de cuidado.'],
['Destinatarios','Familias, estudiantes, vecinos y otros grupos de la comunidad.'],
['Características','Mensajes breves, claros, respetuosos y comprensibles para sus destinatarios.']]],
['Estructuras para carteles y mensajes',[
['Eñangareko ne memby rehe','Cuidá a tu hijo o hija. Expresa una indicación de cuidado.'],
['Ani repita','No fumes. «Ani» introduce una prohibición o advertencia.'],
['Ani re’urei pohã','No tomes medicamentos sin necesidad o sin orientación adecuada.'],
['Eheka pohãnohára ha ani repyta reínte','Buscá un médico y no te quedes sin hacer nada. Orienta a buscar atención.']]],
['El mensaje oral y escrito de campaña',[
['Estructura básica','Tema de salud, acción concreta de prevención y orientación para buscar ayuda.'],
['Forma oral y forma escrita','Oral: pronunciación clara y tono respetuoso. Escrita: frases cortas y letras legibles.'],
['Ejemplo teórico: prevención del dengue','Eliminar recipientes que acumulen agua. Ante síntomas, buscar atención médica y evitar la automedicación.'],
['Otros temas de campaña','Prevención de la diabetes y del embarazo adolescente, con información clara y sin estigmatizar.']]]];
function shape(s,x,y,w,h,fill){return s.shapes.add({geometry:'rect',position:{left:x,top:y,width:w,height:h},fill,line:{fill:'none',width:0}})}
function txt(s,t,x,y,w,h,size,color='#163C36',bold=false){let a=shape(s,x,y,w,h,'none');a.text=t;a.text.style={fontFamily:'Arial',fontSize:size,color,bold};}
for(let i=0;i<data.length;i++){
let [title,rows]=data[i];let s=p.slides.add();s.background.fill='#F3F7F4';shape(s,0,0,18,720,'#237A68');txt(s,title,70,48,1140,100,42,'#163C36',true);shape(s,70,150,1140,3,'#E6B85A');
let step=rows.length===4?112:rows.length===3?145:210;
rows.forEach(([a,b],j)=>{let y=185+j*step;txt(s,a,75,y,1130,46,rows.length===4?29:33,'#237A68',true);txt(s,b,75,y+48,1110,rows.length===2?120:70,26);});
txt(s,'Guaraní · Salud y comunidad',75,670,900,25,17,'#48665F');txt(s,`${i+1} / 7`,1130,670,100,25,17,'#48665F');
s.speakerNotes.text='Material teórico según el temario del usuario. Traducciones contextualizadas. Py’a se interpreta como estómago en el contexto alimentario. Referencia léxica: https://www.mec.gob.ar/descargas/Bibliograf%C3%ADa/Educaci%C3%B3n%20Intercultural%20Biling%C3%BCe/GUARANI/avane-Diccionario-Guarani-Esp-Esp-Guarani.pdf';
if(i===6)s.speakerNotes.text+=' Fuente de prevención del dengue: https://www.mspbs.gov.py/portal/35882/dengue-prevencion-de-criaderos-para-mantener-baja-circulacion-del-virus.html';
await fs.writeFile(`${root}/build/slide-${i+1}.png`,new Uint8Array(await (await p.export({slide:s,format:'png',scale:1})).arrayBuffer()));
}
await (await PresentationFile.exportPptx(p)).save(`${root}/build/draft.pptx`);
const skill='C:/Users/user/.codex/plugins/cache/openai-primary-runtime/presentations/26.1119.11507/skills/presentations';
const {finalizePresentation}=await import(`file:///${skill}/container_tools/artifact_tool_utils.mjs`);
console.log(await finalizePresentation({workspaceDir:root,candidatePath:`${root}/build/draft.pptx`,finalPath:`${root}/output/Autocuidado_y_campanas_de_salud.pptx`,pythonExecutable:'C:/Users/user/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe',integrityValidatorPath:`${skill}/container_tools/inspect_presentation_package_integrity.py`,layoutValidatorPath:`${skill}/container_tools/inspect_presentation_layout_geometry.py`,layoutArgs:['--expected-slide-size-emu','12192000,6858000','--validate-heading-fit'],explicitTotalSlideCount:7,fontPolicy:{basis:'design',families:['Arial']},verifyArtifactToolImport:true,receiptPath:`${root}/build/validation.json`}));

